import 'phoneme_diff.dart';

class PronunciationAttempt {
  final String id;
  final String userId;
  final String sentenceId;
  final String? sessionId;
  final String audioUrl;
  final double overallScore;
  final String? recognizedText;
  final String expectedIpa;
  final String actualIpa;
  final List<WordPhonemeDiff> phonemeDiff;
  final String feedbackText;
  final String? recommendedLessonId;
  final DateTime createdAt;

  const PronunciationAttempt({
    required this.id,
    required this.userId,
    required this.sentenceId,
    this.sessionId,
    required this.audioUrl,
    required this.overallScore,
    this.recognizedText,
    required this.expectedIpa,
    required this.actualIpa,
    required this.phonemeDiff,
    required this.feedbackText,
    this.recommendedLessonId,
    required this.createdAt,
  });

  factory PronunciationAttempt.fromJson(Map<String, dynamic> json) {
    List<WordPhonemeDiff> parsedDiff = [];
    if (json['phoneme_diff_json'] != null) {
      final rawDiff = json['phoneme_diff_json'];
      if (rawDiff is List) {
        parsedDiff = rawDiff
            .map((item) => WordPhonemeDiff.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    return PronunciationAttempt(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sentenceId: json['sentence_id'] as String,
      sessionId: json['session_id'] as String?,
      audioUrl: json['audio_url'] as String,
      overallScore: (json['overall_score'] as num).toDouble(),
      recognizedText: json['recognized_text'] as String?,
      expectedIpa: json['expected_ipa'] as String,
      actualIpa: json['actual_ipa'] as String,
      phonemeDiff: parsedDiff,
      feedbackText: json['feedback_text'] as String,
      recommendedLessonId: json['recommended_lesson_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'sentence_id': sentenceId,
      'session_id': sessionId,
      'audio_url': audioUrl,
      'overall_score': overallScore,
      'recognized_text': recognizedText,
      'expected_ipa': expectedIpa,
      'actual_ipa': actualIpa,
      'phoneme_diff_json': phonemeDiff.map((d) => d.toJson()).toList(),
      'feedback_text': feedbackText,
      'recommended_lesson_id': recommendedLessonId,
    };
  }
}

