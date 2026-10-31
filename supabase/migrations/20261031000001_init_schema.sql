-- ==============================================================================
-- Migration: 20261031000001_init_schema.sql
-- Description: Core Schema, Gamification/Streak Engine, and Pronunciation AI Storage
-- Author: Principal Architect & Supabase Specialist
-- Target: Supabase (PostgreSQL 15+)
-- ==============================================================================

-- 1. EXTENSIONS SETUP
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 2. ENUMS & DOMAINS
-- ==============================================================================
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'difficulty_level_enum') THEN
        CREATE TYPE difficulty_level_enum AS ENUM ('beginner', 'intermediate', 'advanced');
    END IF;
END $$;

-- ==============================================================================
-- 3. TABLES DDL
-- ==============================================================================

-- 3.1 PROFILES TABLE
-- Extends Supabase auth.users with app-specific discipline and streak settings
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    daily_goal_minutes INTEGER NOT NULL DEFAULT 15 CHECK (daily_goal_minutes > 0 AND daily_goal_minutes <= 360),
    current_streak INTEGER NOT NULL DEFAULT 0 CHECK (current_streak >= 0),
    longest_streak INTEGER NOT NULL DEFAULT 0 CHECK (longest_streak >= 0),
    last_practice_date DATE,
    reminder_time TIME NOT NULL DEFAULT '20:00:00',
    timezone TEXT NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 3.2 LESSONS AND SENTENCES TABLE
-- Standard curriculum items with expected IPA and target phonetic focus
CREATE TABLE IF NOT EXISTS public.lessons_and_sentences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category TEXT NOT NULL, -- e.g., 'vowels', 'diphthongs', 'consonants', 'stress_intonation', 'business_phrases'
    target_text TEXT NOT NULL,
    standard_ipa TEXT NOT NULL,
    difficulty_level difficulty_level_enum NOT NULL DEFAULT 'beginner',
    target_phoneme TEXT NOT NULL, -- e.g., 'θ', 'ð', 'æ', 'ʃ', 'tʃ'
    audio_guide_url TEXT, -- Reference native audio guide
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 3.3 PRACTICE SESSIONS TABLE
-- Discipline tracking: logged whenever a user completes a learning/practice block
CREATE TABLE IF NOT EXISTS public.practice_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    duration_seconds INTEGER NOT NULL CHECK (duration_seconds >= 0),
    practiced_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 3.4 PRONUNCIATION ATTEMPTS TABLE
-- Detailed AI assessment metrics, phoneme diffs, audio evidence, and corrective recommendations
CREATE TABLE IF NOT EXISTS public.pronunciation_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    sentence_id UUID NOT NULL REFERENCES public.lessons_and_sentences(id) ON DELETE CASCADE,
    session_id UUID REFERENCES public.practice_sessions(id) ON DELETE SET NULL,
    audio_url TEXT NOT NULL,
    overall_score NUMERIC(5, 2) NOT NULL CHECK (overall_score >= 0.00 AND overall_score <= 100.00),
    recognized_text TEXT,
    expected_ipa TEXT NOT NULL,
    actual_ipa TEXT NOT NULL,
    phoneme_diff_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    feedback_text TEXT NOT NULL, -- Actionable Vietnamese feedback
    recommended_lesson_id UUID REFERENCES public.lessons_and_sentences(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- 4. PERFORMANCE INDEXES
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_profiles_last_practice_date ON public.profiles(last_practice_date);
CREATE INDEX IF NOT EXISTS idx_lessons_category ON public.lessons_and_sentences(category);
CREATE INDEX IF NOT EXISTS idx_lessons_difficulty ON public.lessons_and_sentences(difficulty_level);
CREATE INDEX IF NOT EXISTS idx_lessons_target_phoneme ON public.lessons_and_sentences(target_phoneme);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON public.practice_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_practiced_at ON public.practice_sessions(practiced_at DESC);
CREATE INDEX IF NOT EXISTS idx_attempts_user_id ON public.pronunciation_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_attempts_sentence_id ON public.pronunciation_attempts(sentence_id);
CREATE INDEX IF NOT EXISTS idx_attempts_created_at ON public.pronunciation_attempts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_attempts_score ON public.pronunciation_attempts(overall_score);

-- GIN Index for JSONB phoneme breakdown queries
CREATE INDEX IF NOT EXISTS idx_attempts_phoneme_diff_gin ON public.pronunciation_attempts USING gin (phoneme_diff_json);

-- ==============================================================================
-- 5. TIMEZONE-AWARE STREAK & PROFILE TRIGGERS
-- ==============================================================================

-- 5.1 AUTH USER SIGNUP TRIGGER -> AUTO CREATE PROFILE
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO public.profiles (
        id, 
        email, 
        full_name, 
        avatar_url,
        timezone
    )
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        NEW.raw_user_meta_data->>'avatar_url',
        COALESCE(NEW.raw_user_meta_data->>'timezone', 'Asia/Ho_Chi_Minh')
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 5.2 TIMEZONE-AWARE STREAK CALCULATION FUNCTION
-- Updates current_streak and longest_streak based on the user's localized practice calendar date
CREATE OR REPLACE FUNCTION public.update_user_streak()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_tz TEXT;
    v_local_practice_date DATE;
    v_last_practice_date DATE;
    v_current_streak INTEGER;
    v_longest_streak INTEGER;
BEGIN
    -- 1. Retrieve the user's current streak state and preferred timezone
    SELECT 
        COALESCE(timezone, 'Asia/Ho_Chi_Minh'),
        last_practice_date,
        current_streak,
        longest_streak
    INTO 
        v_user_tz,
        v_last_practice_date,
        v_current_streak,
        v_longest_streak
    FROM public.profiles
    WHERE id = NEW.user_id
    FOR UPDATE; -- Prevent race conditions from concurrent session submissions

    -- 2. Convert UTC session timestamp to the user's local calendar DATE
    BEGIN
        v_local_practice_date := (NEW.practiced_at AT TIME ZONE v_user_tz)::DATE;
    EXCEPTION WHEN OTHERS THEN
        -- Fallback to UTC if timezone string is malformed
        v_local_practice_date := (NEW.practiced_at AT TIME ZONE 'UTC')::DATE;
    END;

    -- 3. Evaluate streak progression
    IF v_last_practice_date IS NULL THEN
        -- First time ever practicing
        v_current_streak := 1;
        v_longest_streak := GREATEST(v_longest_streak, 1);
        v_last_practice_date := v_local_practice_date;

    ELSIF v_local_practice_date = v_last_practice_date THEN
        -- Practiced again on the same calendar day: maintain streak, do not double-increment
        NULL;

    ELSIF v_local_practice_date = (v_last_practice_date + INTERVAL '1 day')::DATE THEN
        -- Practiced on the exact consecutive calendar day: increment streak
        v_current_streak := v_current_streak + 1;
        v_longest_streak := GREATEST(v_longest_streak, v_current_streak);
        v_last_practice_date := v_local_practice_date;

    ELSIF v_local_practice_date > (v_last_practice_date + INTERVAL '1 day')::DATE THEN
        -- Missed 1 or more days: streak reset to 1
        v_current_streak := 1;
        v_last_practice_date := v_local_practice_date;

    ELSE
        -- Edge case: v_local_practice_date < v_last_practice_date
        -- (e.g., late sync of an older offline session). Do not reset current streak.
        NULL;
    END IF;

    -- 4. Persist updated streak metrics back to the profile
    UPDATE public.profiles
    SET 
        current_streak = v_current_streak,
        longest_streak = v_longest_streak,
        last_practice_date = v_last_practice_date,
        updated_at = timezone('utc'::text, now())
    WHERE id = NEW.user_id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_user_streak ON public.practice_sessions;
CREATE TRIGGER trg_update_user_streak
    AFTER INSERT ON public.practice_sessions
    FOR EACH ROW EXECUTE FUNCTION public.update_user_streak();

-- ==============================================================================
-- 6. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

-- Enable RLS across all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lessons_and_sentences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.practice_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pronunciation_attempts ENABLE ROW LEVEL SECURITY;

-- 6.1 PROFILES POLICIES
CREATE POLICY "Users can view own profile"
    ON public.profiles
    FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- 6.2 LESSONS AND SENTENCES POLICIES (Curriculum is read-only for authenticated learners)
CREATE POLICY "Authenticated users can read all lessons"
    ON public.lessons_and_sentences
    FOR SELECT
    TO authenticated
    USING (true);

-- 6.3 PRACTICE SESSIONS POLICIES
CREATE POLICY "Users can view own practice sessions"
    ON public.practice_sessions
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own practice sessions"
    ON public.practice_sessions
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own practice sessions"
    ON public.practice_sessions
    FOR DELETE
    USING (auth.uid() = user_id);

-- 6.4 PRONUNCIATION ATTEMPTS POLICIES
CREATE POLICY "Users can view own attempts"
    ON public.pronunciation_attempts
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own attempts"
    ON public.pronunciation_attempts
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own attempts"
    ON public.pronunciation_attempts
    FOR DELETE
    USING (auth.uid() = user_id);

-- ==============================================================================
-- 7. SUPABASE STORAGE BUCKET & STORAGE RLS POLICIES
-- ==============================================================================

-- Insert private audio storage bucket if it does not already exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'audio-recordings', 
    'audio-recordings', 
    false, -- Private bucket: access protected via signed URLs or authenticated RLS
    10485760, -- 10MB limit per recording
    ARRAY['audio/wav', 'audio/x-wav', 'audio/webm', 'audio/ogg', 'audio/mp4', 'audio/m4a']
)
ON CONFLICT (id) DO UPDATE SET
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage Policy: Users can only upload audio into their dedicated personal subfolder: <user_id>/<filename>
CREATE POLICY "Allow users to upload audio to their own folder"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'audio-recordings' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Storage Policy: Users can read/stream their own audio files
CREATE POLICY "Allow users to read their own audio recordings"
    ON storage.objects
    FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'audio-recordings' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Storage Policy: Users can delete their own audio files
CREATE POLICY "Allow users to delete their own audio recordings"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'audio-recordings' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- ==============================================================================
-- 8. SEED DATA FOR LESSONS (SAMPLE PHONEMES & SENTENCES)
-- ==============================================================================
INSERT INTO public.lessons_and_sentences (category, target_text, standard_ipa, difficulty_level, target_phoneme)
VALUES 
    ('consonants', 'Think through three thin things.', '/θɪŋk θruː θriː θɪn θɪŋz/', 'intermediate', 'θ'),
    ('consonants', 'This brother breathes together with that mother.', '/ðɪs ˈbrʌð.ər briːðz təˈɡɛð.ər wɪð ðæt ˈmʌð.ər/', 'intermediate', 'ð'),
    ('vowels', 'The cat sat on the black mat.', '/ðə kæt sæt ɒn ðə blæk mæt/', 'beginner', 'æ'),
    ('vowels', 'She sells sea shells by the sea shore.', '/ʃiː sɛlz siː ʃɛlz baɪ ðə siː ʃɔːr/', 'advanced', 'ʃ'),
    ('business_phrases', 'We need to prioritize customer satisfaction.', '/wiː niːd tuː praɪˈɒr.ɪ.taɪz ˈkʌs.tə.mər ˌsæt.ɪsˈfæk.ʃən/', 'advanced', 'praɪˈɒr.ɪ.taɪz')
ON CONFLICT DO NOTHING;

