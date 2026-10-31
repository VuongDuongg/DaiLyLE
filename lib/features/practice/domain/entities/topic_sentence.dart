class TopicSentence {
  final String id;
  final String topicId;
  final String sentenceEn;
  final String standardIpa;
  final String meaningVi;
  final String? sampleAudioUrl;
  final String difficulty;
  final int orderIndex;
  final int? userBestScore;

  const TopicSentence({
    required this.id,
    required this.topicId,
    required this.sentenceEn,
    required this.standardIpa,
    required this.meaningVi,
    this.sampleAudioUrl,
    this.difficulty = 'easy',
    this.orderIndex = 0,
    this.userBestScore,
  });

  TopicSentence copyWith({
    int? userBestScore,
  }) {
    return TopicSentence(
      id: id,
      topicId: topicId,
      sentenceEn: sentenceEn,
      standardIpa: standardIpa,
      meaningVi: meaningVi,
      sampleAudioUrl: sampleAudioUrl,
      difficulty: difficulty,
      orderIndex: orderIndex,
      userBestScore: userBestScore ?? this.userBestScore,
    );
  }

  factory TopicSentence.fromJson(Map<String, dynamic> json, {int? bestScore}) {
    return TopicSentence(
      id: json['id'] as String,
      topicId: json['topic_id'] as String? ?? '',
      sentenceEn: json['sentence_en'] as String? ?? '',
      standardIpa: json['standard_ipa'] as String? ?? '',
      meaningVi: json['meaning_vi'] as String? ?? '',
      sampleAudioUrl: json['sample_audio_url'] as String?,
      difficulty: json['difficulty'] as String? ?? 'easy',
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      userBestScore: bestScore ?? (json['user_best_score'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic_id': topicId,
      'sentence_en': sentenceEn,
      'standard_ipa': standardIpa,
      'meaning_vi': meaningVi,
      'sample_audio_url': sampleAudioUrl,
      'difficulty': difficulty,
      'order_index': orderIndex,
    };
  }
}

