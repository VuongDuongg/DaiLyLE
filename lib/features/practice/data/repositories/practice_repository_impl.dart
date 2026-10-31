import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_tables.dart';
import '../../../../core/storage/progress_storage_service.dart';
import '../../../pronunciation/domain/entities/assessment_result.dart';
import '../../domain/entities/topic.dart';
import '../../domain/entities/topic_sentence.dart';
import '../../domain/repositories/practice_repository.dart';

class PracticeRepositoryImpl implements IPracticeRepository {
  final SupabaseClient? _client;

  PracticeRepositoryImpl({SupabaseClient? client}) : _client = client;

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Topic>> getTopics() async {
    final client = _supabase;
    if (client != null) {
      try {
        final response = await client
            .from(SupabaseTables.topics)
            .select()
            .order('created_at', ascending: true);

        final list = (response as List<dynamic>)
            .map((item) => Topic.fromJson(item as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) {
          final storage = ProgressStorageService();
          await storage.init();
          return storage.getTopics(list, fallbackSentences);
        }
      } catch (e) {
        debugPrint('[PracticeRepo] Supabase getTopics error: $e. Using persistent storage.');
      }
    }

    final storage = ProgressStorageService();
    await storage.init();
    return storage.getTopics(fallbackTopics, fallbackSentences);
  }

  @override
  Future<List<TopicSentence>> getTopicSentences(String topicId) async {
    final client = _supabase;
    if (client != null) {
      try {
        final response = await client
            .from(SupabaseTables.topicSentences)
            .select()
            .eq('topic_id', topicId)
            .order('order_index', ascending: true);

        final list = (response as List<dynamic>)
            .map((item) => TopicSentence.fromJson(item as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) {
          final storage = ProgressStorageService();
          await storage.init();
          return storage.getTopicSentences(topicId, list);
        }
      } catch (e) {
        debugPrint('[PracticeRepo] Supabase getTopicSentences error: $e. Using persistent storage.');
      }
    }

    final storage = ProgressStorageService();
    await storage.init();
    return storage.getTopicSentences(topicId, fallbackSentences);
  }

  @override
  Future<void> saveSentenceAttempt({
    required String sentenceId,
    required int score,
    String? topicId,
    List<PhonemeAnalysisItem>? phonemeAnalysis,
  }) async {
    // 1. Persistent Local Storage (Immediate, offline & Web persistent)
    final storage = ProgressStorageService();
    await storage.init();
    await storage.recordSentenceAttempt(
      sentenceId: sentenceId,
      topicId: topicId ?? _findTopicIdForSentence(sentenceId),
      score: score,
      durationSeconds: 90,
      phonemeAnalysis: phonemeAnalysis,
    );

    // 2. Supabase Cloud Sync (if connected and authenticated)
    final client = _supabase;
    if (client != null) {
      try {
        final user = client.auth.currentUser;
        if (user != null) {
          await client.from(SupabaseTables.pronunciationAttempts).insert({
            'user_id': user.id,
            'sentence_id': sentenceId,
            'overall_score': score,
          });
        }
      } catch (e) {
        debugPrint('[PracticeRepo] saveSentenceAttempt cloud sync: $e');
      }
    }
  }

  String _findTopicIdForSentence(String sentenceId) {
    for (final s in fallbackSentences) {
      if (s.id == sentenceId) return s.topicId;
    }
    return 'topic-1';
  }

  // High-fidelity fallback topics matching the database seed
  static final List<Topic> fallbackTopics = [
    const Topic(
      id: 'topic-1',
      nameEn: 'Daily Greetings & Introductions',
      nameVi: 'Chào hỏi & Giao tiếp hằng ngày',
      iconName: 'waving_hand',
      description: 'Luyện phát âm các mẫu câu chào hỏi, giới thiệu bản thân tự nhiên như người bản xứ.',
      totalSentences: 5,
      completedSentences: 3,
    ),
    const Topic(
      id: 'topic-2',
      nameEn: 'Ordering at a Café & Restaurant',
      nameVi: 'Gọi món tại quán Café & Nhà hàng',
      iconName: 'local_cafe',
      description: 'Thực hành gọi đồ uống, đặt bàn và thanh toán hóa đơn lưu loát.',
      totalSentences: 5,
      completedSentences: 1,
    ),
    const Topic(
      id: 'topic-3',
      nameEn: 'Asking for Directions & Travel',
      nameVi: 'Hỏi đường & Du lịch',
      iconName: 'explore',
      description: 'Tự tin hỏi đường, đi tàu xe và hỏi thông tin khi du lịch nước ngoài.',
      totalSentences: 5,
      completedSentences: 0,
    ),
    const Topic(
      id: 'topic-4',
      nameEn: 'Work & Office Communication',
      nameVi: 'Giao tiếp nơi công sở',
      iconName: 'business_center',
      description: 'Nâng cao khả năng phát âm trong các cuộc họp, thuyết trình và trao đổi công việc.',
      totalSentences: 5,
      completedSentences: 2,
    ),
  ];

  static final List<TopicSentence> fallbackSentences = [
    // Topic 1
    const TopicSentence(
      id: 't1-s1',
      topicId: 'topic-1',
      sentenceEn: 'Good morning, how are you today?',
      standardIpa: '/ɡʊd ˈmɔːr.nɪŋ, haʊ ɑːr juː təˈdeɪ/',
      meaningVi: 'Chào buổi sáng, hôm nay bạn thế nào?',
      difficulty: 'easy',
      orderIndex: 1,
      userBestScore: 88,
    ),
    const TopicSentence(
      id: 't1-s2',
      topicId: 'topic-1',
      sentenceEn: 'Nice to meet you, my name is Alex.',
      standardIpa: '/naɪs tuː miːt juː, maɪ neɪm ɪz ˈæl.ɪks/',
      meaningVi: 'Rất vui được gặp bạn, tôi tên là Alex.',
      difficulty: 'easy',
      orderIndex: 2,
      userBestScore: 92,
    ),
    const TopicSentence(
      id: 't1-s3',
      topicId: 'topic-1',
      sentenceEn: 'Have a wonderful weekend ahead!',
      standardIpa: '/hæv ə ˈwʌn.dər.fəl ˈwiːk.ɛnd əˈhɛd/',
      meaningVi: 'Chúc bạn một cuối tuần thật tuyệt vời!',
      difficulty: 'easy',
      orderIndex: 3,
      userBestScore: 78,
    ),
    const TopicSentence(
      id: 't1-s4',
      topicId: 'topic-1',
      sentenceEn: 'Long time no see, how have you been?',
      standardIpa: '/lɒŋ taɪm noʊ siː, haʊ hæv juː biːn/',
      meaningVi: 'Lâu rồi không gặp, dạo này bạn thế nào?',
      difficulty: 'medium',
      orderIndex: 4,
    ),
    const TopicSentence(
      id: 't1-s5',
      topicId: 'topic-1',
      sentenceEn: 'Could you please speak a little slower?',
      standardIpa: '/kʊd juː pliːz spiːk ə ˈlɪt.əl ˈsloʊ.ər/',
      meaningVi: 'Bạn có thể nói chậm lại một chút được không?',
      difficulty: 'medium',
      orderIndex: 5,
    ),

    // Topic 2
    const TopicSentence(
      id: 't2-s1',
      topicId: 'topic-2',
      sentenceEn: 'Could I have an iced latte with oat milk, please?',
      standardIpa: '/kʊd aɪ hæv ən aɪst ˈlɑː.teɪ wɪð oʊt mɪlk, pliːz/',
      meaningVi: 'Cho tôi một ly latte đá với sữa yến mạch được không?',
      difficulty: 'easy',
      orderIndex: 1,
      userBestScore: 82,
    ),
    const TopicSentence(
      id: 't2-s2',
      topicId: 'topic-2',
      sentenceEn: 'Can we get the bill, please?',
      standardIpa: '/kæn wiː ɡɛt ðə bɪl, pliːz/',
      meaningVi: 'Làm ơn cho chúng tôi xin hóa đơn thanh toán.',
      difficulty: 'easy',
      orderIndex: 2,
    ),
    const TopicSentence(
      id: 't2-s3',
      topicId: 'topic-2',
      sentenceEn: 'What do you recommend for dessert?',
      standardIpa: '/wɒt duː juː ˌrɛk.əˈmɛnd fɔːr dɪˈzɜːrt/',
      meaningVi: 'Bạn có gợi ý món tráng miệng nào ngon không?',
      difficulty: 'medium',
      orderIndex: 3,
    ),
    const TopicSentence(
      id: 't2-s4',
      topicId: 'topic-2',
      sentenceEn: 'Is there any vegetarian option on the menu?',
      standardIpa: '/ɪz ðɛər ˈɛn.i ˌvɛdʒ.ɪˈtɛə.ri.ən ˈɒp.ʃən ɒn ðə ˈmɛn.juː/',
      meaningVi: 'Trong thực đơn có món chay nào không?',
      difficulty: 'medium',
      orderIndex: 4,
    ),
    const TopicSentence(
      id: 't2-s5',
      topicId: 'topic-2',
      sentenceEn: 'I would like to make a table reservation for tonight.',
      standardIpa: '/aɪ wʊd laɪk tuː meɪk ə ˈteɪ.bəl ˌrɛz.ərˈveɪ.ʃən fɔːr təˈnaɪt/',
      meaningVi: 'Tôi muốn đặt một bàn cho tối nay.',
      difficulty: 'hard',
      orderIndex: 5,
    ),

    // Topic 3
    const TopicSentence(
      id: 't3-s1',
      topicId: 'topic-3',
      sentenceEn: 'Excuse me, where is the nearest subway station?',
      standardIpa: '/ɪkˈskjuːz miː, wɛər ɪz ðə ˈnɪə.rɪst ˈsʌb.weɪ ˈsteɪ.ʃən/',
      meaningVi: 'Xin lỗi, ga tàu điện ngầm gần nhất ở đâu ạ?',
      difficulty: 'easy',
      orderIndex: 1,
    ),
    const TopicSentence(
      id: 't3-s2',
      topicId: 'topic-3',
      sentenceEn: 'How far is it from here to the museum?',
      standardIpa: '/haʊ fɑːr ɪz ɪt frɒm hɪər tuː ðə mjuːˈziː.əm/',
      meaningVi: 'Từ đây đến viện bảo tàng cách bao xa?',
      difficulty: 'easy',
      orderIndex: 2,
    ),
    const TopicSentence(
      id: 't3-s3',
      topicId: 'topic-3',
      sentenceEn: 'Turn left at the traffic light and go straight.',
      standardIpa: '/tɜːrn lɛft æt ðə ˈtræf.ɪk laɪt ænd ɡoʊ streɪt/',
      meaningVi: 'Rẽ trái ở cột đèn giao thông rồi đi thẳng.',
      difficulty: 'medium',
      orderIndex: 3,
    ),
    const TopicSentence(
      id: 't3-s4',
      topicId: 'topic-3',
      sentenceEn: 'Can you show me this address on Google Maps?',
      standardIpa: '/kæn juː ʃoʊ miː ðɪs əˈdrɛs ɒn ˈɡuː.ɡəl mæps/',
      meaningVi: 'Bạn có thể chỉ giúp tôi địa chỉ này trên bản đồ không?',
      difficulty: 'medium',
      orderIndex: 4,
    ),
    const TopicSentence(
      id: 't3-s5',
      topicId: 'topic-3',
      sentenceEn: 'I need to check in for my flight to Tokyo.',
      standardIpa: '/aɪ niːd tuː tʃɛk ɪn fɔːr maɪ flaɪt tuː ˈtoʊ.kjoʊ/',
      meaningVi: 'Tôi cần làm thủ tục lên máy bay cho chuyến bay tới Tokyo.',
      difficulty: 'hard',
      orderIndex: 5,
    ),

    // Topic 4
    const TopicSentence(
      id: 't4-s1',
      topicId: 'topic-4',
      sentenceEn: 'Could you send me the latest progress report?',
      standardIpa: '/kʊd juː sɛnd miː ðə ˈleɪ.tɪst ˈproʊ.ɡrɛs rɪˈpɔːrt/',
      meaningVi: 'Bạn có thể gửi cho tôi bản báo cáo tiến độ mới nhất không?',
      difficulty: 'easy',
      orderIndex: 1,
      userBestScore: 90,
    ),
    const TopicSentence(
      id: 't4-s2',
      topicId: 'topic-4',
      sentenceEn: 'Let\'s schedule a quick sync meeting tomorrow morning.',
      standardIpa: '/lɛts ˈskɛdʒ.uːl ə kwɪk sɪŋk ˈmiː.tɪŋ təˈmɒr.oʊ ˈmɔːr.nɪŋ/',
      meaningVi: 'Hãy lên lịch một cuộc họp ngắn vào sáng mai nhé.',
      difficulty: 'medium',
      orderIndex: 2,
      userBestScore: 84,
    ),
    const TopicSentence(
      id: 't4-s3',
      topicId: 'topic-4',
      sentenceEn: 'I will follow up with you via email by the end of the day.',
      standardIpa: '/aɪ wɪl ˈfɒl.oʊ ʌp wɪð juː ˈvaɪ.ə ˈiː.meɪl baɪ ðiː ɛnd ɒv ðə deɪ/',
      meaningVi: 'Tôi sẽ phản hồi lại cho bạn qua email trước cuối ngày hôm nay.',
      difficulty: 'medium',
      orderIndex: 3,
    ),
    const TopicSentence(
      id: 't4-s4',
      topicId: 'topic-4',
      sentenceEn: 'We need to prioritize customer satisfaction.',
      standardIpa: '/wiː niːd tuː praɪˈɒr.ɪ.taɪz ˈkʌs.tə.mər ˌsæt.ɪsˈfæk.ʃən/',
      meaningVi: 'Chúng ta cần ưu tiên hàng đầu sự hài lòng của khách hàng.',
      difficulty: 'medium',
      orderIndex: 4,
    ),
    const TopicSentence(
      id: 't4-s5',
      topicId: 'topic-4',
      sentenceEn: 'I really appreciate your timely feedback and support.',
      standardIpa: '/aɪ ˈrɪə.li əˈpriː.ʃi.eɪt jɔːr ˈtaɪm.li ˈfiːd.bæk ænd səˈpɔːrt/',
      meaningVi: 'Tôi rất cảm kích sự phản hồi kịp thời và hỗ trợ nhiệt tình của bạn.',
      difficulty: 'hard',
      orderIndex: 5,
    ),
  ];
}

