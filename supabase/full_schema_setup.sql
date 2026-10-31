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

-- ==============================================================================
-- Migration: 20261031000002_topic_sentences.sql
-- Description: Topic-Based Pronunciation Modules & Conversational Sentences
-- Target: Supabase (PostgreSQL 15+)
-- ==============================================================================

-- 1. TOPICS TABLE
CREATE TABLE IF NOT EXISTS public.topics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name_en TEXT NOT NULL,
    name_vi TEXT NOT NULL,
    icon_name TEXT NOT NULL DEFAULT 'chat',
    description TEXT,
    total_sentences INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. TOPIC SENTENCES TABLE
CREATE TABLE IF NOT EXISTS public.topic_sentences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic_id UUID NOT NULL REFERENCES public.topics(id) ON DELETE CASCADE,
    sentence_en TEXT NOT NULL,
    standard_ipa TEXT NOT NULL,
    meaning_vi TEXT NOT NULL,
    sample_audio_url TEXT,
    difficulty TEXT NOT NULL CHECK (difficulty IN ('easy', 'medium', 'hard')) DEFAULT 'easy',
    order_index INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Indexes for performant lookup
CREATE INDEX IF NOT EXISTS idx_topic_sentences_topic_id ON public.topic_sentences(topic_id);
CREATE INDEX IF NOT EXISTS idx_topic_sentences_order ON public.topic_sentences(topic_id, order_index ASC);

-- 3. ENABLE ROW LEVEL SECURITY (RLS)
ALTER TABLE public.topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.topic_sentences ENABLE ROW LEVEL SECURITY;

-- Topics & Sentences are readable by all authenticated learners and visitors
CREATE POLICY "Public read access for topics"
    ON public.topics FOR SELECT
    USING (true);

CREATE POLICY "Public read access for topic sentences"
    ON public.topic_sentences FOR SELECT
    USING (true);

-- 4. SEED TOPICS & CONVERSATIONAL SENTENCES
DO $$
DECLARE
    v_topic1_id UUID := gen_random_uuid();
    v_topic2_id UUID := gen_random_uuid();
    v_topic3_id UUID := gen_random_uuid();
    v_topic4_id UUID := gen_random_uuid();
BEGIN
    -- TOPIC 1: Daily Greetings & Introductions
    INSERT INTO public.topics (id, name_en, name_vi, icon_name, description, total_sentences)
    VALUES (
        v_topic1_id,
        'Daily Greetings & Introductions',
        'Chào hỏi & Giao tiếp hằng ngày',
        'waving_hand',
        'Luyện phát âm các mẫu câu chào hỏi, giới thiệu bản thân tự nhiên như người bản xứ.',
        5
    );

    INSERT INTO public.topic_sentences (topic_id, sentence_en, standard_ipa, meaning_vi, difficulty, order_index)
    VALUES
        (v_topic1_id, 'Good morning, how are you today?', '/ɡʊd ˈmɔːr.nɪŋ, haʊ ɑːr juː təˈdeɪ/', 'Chào buổi sáng, hôm nay bạn thế nào?', 'easy', 1),
        (v_topic1_id, 'Nice to meet you, my name is Alex.', '/naɪs tuː miːt juː, maɪ neɪm ɪz ˈæl.ɪks/', 'Rất vui được gặp bạn, tôi tên là Alex.', 'easy', 2),
        (v_topic1_id, 'Have a wonderful weekend ahead!', '/hæv ə ˈwʌn.dər.fəl ˈwiːk.ɛnd əˈhɛd/', 'Chúc bạn một cuối tuần thật tuyệt vời!', 'easy', 3),
        (v_topic1_id, 'Long time no see, how have you been?', '/lɒŋ taɪm noʊ siː, haʊ hæv juː biːn/', 'Lâu rồi không gặp, dạo này bạn thế nào?', 'medium', 4),
        (v_topic1_id, 'Could you please speak a little slower?', '/kʊd juː pliːz spiːk ə ˈlɪt.əl ˈsloʊ.ər/', 'Bạn có thể nói chậm lại một chút được không?', 'medium', 5);

    -- TOPIC 2: Ordering at a Café & Restaurant
    INSERT INTO public.topics (id, name_en, name_vi, icon_name, description, total_sentences)
    VALUES (
        v_topic2_id,
        'Ordering at a Café & Restaurant',
        'Gọi món tại quán Café & Nhà hàng',
        'local_cafe',
        'Thực hành gọi đồ uống, đặt bàn và thanh toán hóa đơn lưu loát.',
        5
    );

    INSERT INTO public.topic_sentences (topic_id, sentence_en, standard_ipa, meaning_vi, difficulty, order_index)
    VALUES
        (v_topic2_id, 'Could I have an iced latte with oat milk, please?', '/kʊd aɪ hæv ən aɪst ˈlɑː.teɪ wɪð oʊt mɪlk, pliːz/', 'Cho tôi một ly latte đá với sữa yến mạch được không?', 'easy', 1),
        (v_topic2_id, 'Can we get the bill, please?', '/kæn wiː ɡɛt ðə bɪl, pliːz/', 'Làm ơn cho chúng tôi xin hóa đơn thanh toán.', 'easy', 2),
        (v_topic2_id, 'What do you recommend for dessert?', '/wɒt duː juː ˌrɛk.əˈmɛnd fɔːr dɪˈzɜːrt/', 'Bạn có gợi ý món tráng miệng nào ngon không?', 'medium', 3),
        (v_topic2_id, 'Is there any vegetarian option on the menu?', '/ɪz ðɛər ˈɛn.i ˌvɛdʒ.ɪˈtɛə.ri.ən ˈɒp.ʃən ɒn ðə ˈmɛn.juː/', 'Trong thực đơn có món chay nào không?', 'medium', 4),
        (v_topic2_id, 'I would like to make a table reservation for tonight.', '/aɪ wʊd laɪk tuː meɪk ə ˈteɪ.bəl ˌrɛz.ərˈveɪ.ʃən fɔːr təˈnaɪt/', 'Tôi muốn đặt một bàn cho tối nay.', 'hard', 5);

    -- TOPIC 3: Asking for Directions & Travel
    INSERT INTO public.topics (id, name_en, name_vi, icon_name, description, total_sentences)
    VALUES (
        v_topic3_id,
        'Asking for Directions & Travel',
        'Hỏi đường & Du lịch',
        'explore',
        'Tự tin hỏi đường, đi tàu xe và hỏi thông tin khi du lịch nước ngoài.',
        5
    );

    INSERT INTO public.topic_sentences (topic_id, sentence_en, standard_ipa, meaning_vi, difficulty, order_index)
    VALUES
        (v_topic3_id, 'Excuse me, where is the nearest subway station?', '/ɪkˈskjuːz miː, wɛər ɪz ðə ˈnɪə.rɪst ˈsʌb.weɪ ˈsteɪ.ʃən/', 'Xin lỗi, ga tàu điện ngầm gần nhất ở đâu ạ?', 'easy', 1),
        (v_topic3_id, 'How far is it from here to the museum?', '/haʊ fɑːr ɪz ɪt frɒm hɪər tuː ðə mjuːˈziː.əm/', 'Từ đây đến viện bảo tàng cách bao xa?', 'easy', 2),
        (v_topic3_id, 'Turn left at the traffic light and go straight.', '/tɜːrn lɛft æt ðə ˈtræf.ɪk laɪt ænd ɡoʊ streɪt/', 'Rẽ trái ở cột đèn giao thông rồi đi thẳng.', 'medium', 3),
        (v_topic3_id, 'Can you show me this address on Google Maps?', '/kæn juː ʃoʊ miː ðɪs əˈdrɛs ɒn ˈɡuː.ɡəl mæps/', 'Bạn có thể chỉ giúp tôi địa chỉ này trên bản đồ không?', 'medium', 4),
        (v_topic3_id, 'I need to check in for my flight to Tokyo.', '/aɪ niːd tuː tʃɛk ɪn fɔːr maɪ flaɪt tuː ˈtoʊ.kjoʊ/', 'Tôi cần làm thủ tục lên máy bay cho chuyến bay tới Tokyo.', 'hard', 5);

    -- TOPIC 4: Work & Office Communication
    INSERT INTO public.topics (id, name_en, name_vi, icon_name, description, total_sentences)
    VALUES (
        v_topic4_id,
        'Work & Office Communication',
        'Giao tiếp nơi công sở',
        'business_center',
        'Nâng cao khả năng phát âm trong các cuộc họp, thuyết trình và trao đổi công việc.',
        5
    );

    INSERT INTO public.topic_sentences (topic_id, sentence_en, standard_ipa, meaning_vi, difficulty, order_index)
    VALUES
        (v_topic4_id, 'Could you send me the latest progress report?', '/kʊd juː sɛnd miː ðə ˈleɪ.tɪst ˈproʊ.ɡrɛs rɪˈpɔːrt/', 'Bạn có thể gửi cho tôi bản báo cáo tiến độ mới nhất không?', 'easy', 1),
        (v_topic4_id, 'Let''s schedule a quick sync meeting tomorrow morning.', '/lɛts ˈskɛdʒ.uːl ə kwɪk sɪŋk ˈmiː.tɪŋ təˈmɒr.oʊ ˈmɔːr.nɪŋ/', 'Hãy lên lịch một cuộc họp ngắn vào sáng mai nhé.', 'medium', 2),
        (v_topic4_id, 'I will follow up with you via email by the end of the day.', '/aɪ wɪl ˈfɒl.oʊ ʌp wɪð juː ˈvaɪ.ə ˈiː.meɪl baɪ ðiː ɛnd ɒv ðə deɪ/', 'Tôi sẽ phản hồi lại cho bạn qua email trước cuối ngày hôm nay.', 'medium', 3),
        (v_topic4_id, 'We need to prioritize customer satisfaction.', '/wiː niːd tuː praɪˈɒr.ɪ.taɪz ˈkʌs.tə.mər ˌsæt.ɪsˈfæk.ʃən/', 'Chúng ta cần ưu tiên hàng đầu sự hài lòng của khách hàng.', 'medium', 4),
        (v_topic4_id, 'I really appreciate your timely feedback and support.', '/aɪ ˈrɪə.li əˈpriː.ʃi.eɪt jɔːr ˈtaɪm.li ˈfiːd.bæk ænd səˈpɔːrt/', 'Tôi rất cảm kích sự phản hồi kịp thời và hỗ trợ nhiệt tình của bạn.', 'hard', 5);

END $$;

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

