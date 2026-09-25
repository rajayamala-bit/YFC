-- =============================================================================
-- YFC (Youth For Christ) PostgreSQL & Supabase Production Database Schema
-- =============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. PROFILES TABLE (Tracking Member Data, Birthdays, Anniversaries, Streaks)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    language_pref TEXT NOT NULL DEFAULT 'EN' CHECK (language_pref IN ('EN', 'TE')),
    birth_date DATE,
    wedding_anniversary DATE,
    prayer_streak INT NOT NULL DEFAULT 0,
    total_points INT NOT NULL DEFAULT 0,
    avatar_url TEXT,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'admin', 'bot')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. GLOBAL FELLOWSHIP CHAT MESSAGES (Single Stream, Voice, Media, Bot, Reactions)
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    sender_name TEXT NOT NULL,
    sender_avatar TEXT,
    message_type TEXT NOT NULL CHECK (message_type IN ('text', 'voice', 'image', 'video', 'bot')),
    text_content TEXT,
    media_url TEXT,
    audio_duration_seconds INT DEFAULT 0,
    reactions JSONB NOT NULL DEFAULT '{"🙏": 0, "❤️": 0, "🔥": 0, "✝️": 0, "📖": 0, "👏": 0}'::jsonb,
    is_system_bot BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. BILINGUAL QUIZZES TABLE (Generated via Gemini API)
CREATE TABLE IF NOT EXISTS public.quizzes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    quiz_date DATE NOT NULL UNIQUE DEFAULT CURRENT_DATE,
    book TEXT NOT NULL,
    chapter INT NOT NULL,
    verses TEXT NOT NULL,
    questions JSONB NOT NULL, -- Array of 5 bilingual MCQ objects
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. QUIZ SUBMISSIONS TABLE (Records User Score & Speed in Seconds)
CREATE TABLE IF NOT EXISTS public.quiz_submissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    quiz_id UUID NOT NULL REFERENCES public.quizzes(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    score INT NOT NULL CHECK (score >= 0 AND score <= 5),
    elapsed_seconds INT NOT NULL CHECK (elapsed_seconds >= 0),
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_quiz UNIQUE (quiz_id, user_id)
);

-- 5. PRAYER REQUESTS TABLE (With Live "I Prayed For This" Counter)
CREATE TABLE IF NOT EXISTS public.prayer_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    author_name TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT DEFAULT 'General',
    pray_count INT NOT NULL DEFAULT 0,
    prayed_by_users JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of user UUID strings
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- VIEWS & FUNCTIONS
-- =============================================================================

-- Champions Podium View (Top 3 Users for Today's Quiz)
CREATE OR REPLACE VIEW public.champions_podium AS
SELECT 
    qs.id AS submission_id,
    qs.quiz_id,
    p.id AS user_id,
    p.full_name,
    p.avatar_url,
    qs.score,
    qs.elapsed_seconds,
    qs.submitted_at,
    RANK() OVER (PARTITION BY qs.quiz_id ORDER BY qs.score DESC, qs.elapsed_seconds ASC) AS rank
FROM public.quiz_submissions qs
JOIN public.profiles p ON qs.user_id = p.id;

-- Function: Increment Prayer Counter atomically
CREATE OR REPLACE FUNCTION public.increment_prayer_count(
    request_id UUID,
    subscriber_user_id TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE public.prayer_requests
    SET 
        pray_count = pray_count + 1,
        prayed_by_users = prayed_by_users || jsonb_build_array(subscriber_user_id)
    WHERE id = request_id
      AND NOT (prayed_by_users @> jsonb_build_array(subscriber_user_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Automated Bot Birthday & Anniversary Broadcaster (Runs at 12:01 AM IST)
CREATE OR REPLACE FUNCTION public.broadcast_daily_celebrations()
RETURNS VOID AS $$
DECLARE
    rec RECORD;
BEGIN
    -- Birthdays
    FOR rec IN 
        SELECT full_name FROM public.profiles 
        WHERE EXTRACT(MONTH FROM birth_date) = EXTRACT(MONTH FROM CURRENT_DATE)
          AND EXTRACT(DAY FROM birth_date) = EXTRACT(DAY FROM CURRENT_DATE)
    LOOP
        INSERT INTO public.chat_messages (sender_name, message_type, text_content, is_system_bot)
        VALUES (
            'YFC Fellowship Bot 🎂', 
            'bot', 
            '🎉 Happy Birthday to ' || rec.full_name || '! May the Lord bless you and keep you! (Numbers 6:24) 🎂✝️', 
            TRUE
        );
    END LOOP;

    -- Anniversaries
    FOR rec IN 
        SELECT full_name FROM public.profiles 
        WHERE EXTRACT(MONTH FROM wedding_anniversary) = EXTRACT(MONTH FROM CURRENT_DATE)
          AND EXTRACT(DAY FROM wedding_anniversary) = EXTRACT(DAY FROM CURRENT_DATE)
    LOOP
        INSERT INTO public.chat_messages (sender_name, message_type, text_content, is_system_bot)
        VALUES (
            'YFC Fellowship Bot 💍', 
            'bot', 
            '💑 Happy Wedding Anniversary to ' || rec.full_name || ' & family! Above all, put on love, which binds everything together in perfect harmony. (Colossians 3:14) ❤️✝️', 
            TRUE
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Realtime Publication for Chat Stream & Prayer Requests
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.prayer_requests;
