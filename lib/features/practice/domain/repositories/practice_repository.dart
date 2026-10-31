import '../../../pronunciation/domain/entities/assessment_result.dart';
import '../entities/topic.dart';
import '../entities/topic_sentence.dart';

abstract class IPracticeRepository {
  /// Fetches available learning topics with completion stats
  Future<List<Topic>> getTopics();

  /// Fetches conversational sentences inside a selected topic
  Future<List<TopicSentence>> getTopicSentences(String topicId);

  /// Records attempt and updates topic progress
  Future<void> saveSentenceAttempt({
    required String sentenceId,
    required int score,
    String? topicId,
    List<PhonemeAnalysisItem>? phonemeAnalysis,
  });
}

