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

