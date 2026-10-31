class LessonSentence {
  final String id;
  final String category;
  final String targetText;
  final String standardIpa;
  final String difficultyLevel;
  final String targetPhoneme;
  final String? audioGuideUrl;
  final DateTime createdAt;

  const LessonSentence({
    required this.id,
    required this.category,
    required this.targetText,
    required this.standardIpa,
    required this.difficultyLevel,
    required this.targetPhoneme,
    this.audioGuideUrl,
    required this.createdAt,
  });

  factory LessonSentence.fromJson(Map<String, dynamic> json) {
    return LessonSentence(
      id: json['id'] as String,
      category: json['category'] as String,
      targetText: json['target_text'] as String,
      standardIpa: json['standard_ipa'] as String,
      difficultyLevel: json['difficulty_level'] as String,
      targetPhoneme: json['target_phoneme'] as String,
      audioGuideUrl: json['audio_guide_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'target_text': targetText,
      'standard_ipa': standardIpa,
      'difficulty_level': difficultyLevel,
      'target_phoneme': targetPhoneme,
      'audio_guide_url': audioGuideUrl,
    };
  }
}

