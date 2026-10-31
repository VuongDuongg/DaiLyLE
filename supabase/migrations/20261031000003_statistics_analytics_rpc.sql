-- ==============================================================================
-- Migration: 20261031000003_statistics_analytics_rpc.sql
-- Description: Analytics RPC functions for Discipline, Streaks & Pronunciation Trends
-- Target: Supabase (PostgreSQL 15+)
-- ==============================================================================

-- 1. GET USER DISCIPLINE & STREAK STATS
CREATE OR REPLACE FUNCTION public.get_user_discipline_stats(p_user_id UUID)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_profile RECORD;
    v_today_date DATE;
    v_today_seconds INTEGER := 0;
    v_today_minutes INTEGER := 0;
    v_is_today_completed BOOLEAN := false;
    v_week_start DATE;
    v_active_days BOOLEAN[] := ARRAY[false, false, false, false, false, false, false];
    v_day_idx INTEGER;
    v_session RECORD;
    v_result JSONB;
BEGIN
    -- 1. Fetch user profile
    SELECT 
        current_streak,
        longest_streak,
        daily_goal_minutes,
        last_practice_date,
        reminder_time,
        timezone
    INTO v_profile
    FROM public.profiles
    WHERE id = p_user_id;

    IF v_profile IS NULL THEN
        RETURN jsonb_build_object(
            'current_streak', 0,
            'longest_streak', 0,
            'daily_goal_minutes', 15,
            'today_minutes', 0,
            'is_today_completed', false,
            'reminder_time', '20:00:00',
            'weekly_active_days', jsonb_build_array(false, false, false, false, false, false, false)
        );
    END IF;

    -- Localized date calculation
    v_today_date := (timezone('utc'::text, now()) AT TIME ZONE COALESCE(v_profile.timezone, 'Asia/Ho_Chi_Minh'))::DATE;

    -- Calculate today's accumulated practice seconds
    SELECT COALESCE(SUM(duration_seconds), 0)
    INTO v_today_seconds
    FROM public.practice_sessions
    WHERE user_id = p_user_id
      AND ((practiced_at AT TIME ZONE COALESCE(v_profile.timezone, 'Asia/Ho_Chi_Minh'))::DATE = v_today_date);

    v_today_minutes := ROUND(v_today_seconds / 60.0);
    v_is_today_completed := (v_today_minutes >= v_profile.daily_goal_minutes) OR (v_profile.last_practice_date = v_today_date);

    -- Calculate active days in current week (Monday to Sunday)
    v_week_start := date_trunc('week', v_today_date)::DATE;

    FOR v_session IN
        SELECT DISTINCT ((practiced_at AT TIME ZONE COALESCE(v_profile.timezone, 'Asia/Ho_Chi_Minh'))::DATE) AS p_date
        FROM public.practice_sessions
        WHERE user_id = p_user_id
          AND ((practiced_at AT TIME ZONE COALESCE(v_profile.timezone, 'Asia/Ho_Chi_Minh'))::DATE >= v_week_start)
    LOOP
        v_day_idx := EXTRACT(DOW FROM v_session.p_date);
        -- In Postgres: 0 = Sun, 1 = Mon ... 6 = Sat
        -- Convert to 1 = Mon (index 1) ... 7 = Sun (index 7)
        IF v_day_idx = 0 THEN
            v_active_days[7] := true;
        ELSE
            v_active_days[v_day_idx] := true;
        END IF;
    END LOOP;

    v_result := jsonb_build_object(
        'current_streak', v_profile.current_streak,
        'longest_streak', v_profile.longest_streak,
        'daily_goal_minutes', v_profile.daily_goal_minutes,
        'today_minutes', v_today_minutes,
        'is_today_completed', v_is_today_completed,
        'reminder_time', v_profile.reminder_time::text,
        'weekly_active_days', to_jsonb(v_active_days)
    );

    RETURN v_result;
END;
$$;

-- 2. GET WEEKLY STUDY TIME (7 DAYS)
CREATE OR REPLACE FUNCTION public.get_weekly_study_minutes(p_user_id UUID)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_tz TEXT;
    v_today DATE;
    v_week_start DATE;
    v_days TEXT[] := ARRAY['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    v_daily_mins DOUBLE PRECISION[] := ARRAY[0, 0, 0, 0, 0, 0, 0];
    v_rec RECORD;
    v_idx INTEGER;
BEGIN
    SELECT COALESCE(timezone, 'Asia/Ho_Chi_Minh') INTO v_user_tz FROM public.profiles WHERE id = p_user_id;
    IF v_user_tz IS NULL THEN v_user_tz := 'Asia/Ho_Chi_Minh'; END IF;

    v_today := (timezone('utc'::text, now()) AT TIME ZONE v_user_tz)::DATE;
    v_week_start := date_trunc('week', v_today)::DATE;

    FOR v_rec IN
        SELECT 
            ((practiced_at AT TIME ZONE v_user_tz)::DATE) as p_date,
            SUM(duration_seconds) as total_sec
        FROM public.practice_sessions
        WHERE user_id = p_user_id
          AND ((practiced_at AT TIME ZONE v_user_tz)::DATE >= v_week_start)
        GROUP BY 1
    LOOP
        v_idx := EXTRACT(DOW FROM v_rec.p_date);
        IF v_idx = 0 THEN
            v_daily_mins[7] := ROUND((v_rec.total_sec / 60.0)::numeric, 1);
        ELSE
            v_daily_mins[v_idx] := ROUND((v_rec.total_sec / 60.0)::numeric, 1);
        END IF;
    END LOOP;

    RETURN to_jsonb(v_daily_mins);
END;
$$;

-- 3. GET HISTORICAL SCORE TRENDS
CREATE OR REPLACE FUNCTION public.get_user_score_trends(p_user_id UUID)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_scores JSONB;
BEGIN
    SELECT jsonb_agg(overall_score ORDER BY created_at ASC)
    INTO v_scores
    FROM (
        SELECT overall_score, created_at
        FROM public.pronunciation_attempts
        WHERE user_id = p_user_id
        ORDER BY created_at DESC
        LIMIT 10
    ) sub;

    RETURN COALESCE(v_scores, '[]'::jsonb);
END;
$$;

-- 4. UPDATE USER DAILY GOAL & REMINDER TIME
CREATE OR REPLACE FUNCTION public.update_user_discipline_settings(
    p_user_id UUID,
    p_new_goal INTEGER DEFAULT NULL,
    p_reminder_time TIME DEFAULT NULL
)
RETURNS VOID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.profiles
    SET 
        daily_goal_minutes = COALESCE(p_new_goal, daily_goal_minutes),
        reminder_time = COALESCE(p_reminder_time, reminder_time),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_user_id;
END;
$$;

