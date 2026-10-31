class PhonemeAnalysisItem {
  final String phoneme;
  final String actual;
  final String status; // 'correct', 'wrong', 'missing', 'extra'
  final String? tip;

  const PhonemeAnalysisItem({
    required this.phoneme,
    required this.actual,
    required this.status,
    this.tip,
  });

  bool get isCorrect => status == 'correct';
  bool get isWrong => status == 'wrong';
  bool get isMissing => status == 'missing';
  bool get isExtra => status == 'extra';

  factory PhonemeAnalysisItem.fromJson(Map<String, dynamic> json) {
    return PhonemeAnalysisItem(
      phoneme: json['phoneme'] as String? ?? '',
      actual: json['actual'] as String? ?? '',
      status: json['status'] as String? ?? 'wrong',
      tip: json['tip'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phoneme': phoneme,
      'actual': actual,
      'status': status,
      if (tip != null) 'tip': tip,
    };
  }
}

class WordAssessment {
  final String word;
  final String expectedIpa;
  final String actualIpa;
  final int score;
  final List<PhonemeAnalysisItem> phonemeAnalysis;

  const WordAssessment({
    required this.word,
    required this.expectedIpa,
    required this.actualIpa,
    required this.score,
    required this.phonemeAnalysis,
  });

  factory WordAssessment.fromJson(Map<String, dynamic> json) {
    return WordAssessment(
      word: json['word'] as String? ?? '',
      expectedIpa: json['expected_ipa'] as String? ?? '',
      actualIpa: json['actual_ipa'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      phonemeAnalysis: (json['phoneme_analysis'] as List<dynamic>?)
              ?.map((e) => PhonemeAnalysisItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'expected_ipa': expectedIpa,
      'actual_ipa': actualIpa,
      'score': score,
      'phoneme_analysis': phonemeAnalysis.map((p) => p.toJson()).toList(),
    };
  }
}

class AssessmentResult {
  final int overallScore;
  final List<WordAssessment> words;
  final String overallFeedback;
  final String recommendedPhonemeDrill;
  final String? audioStorageUrl;
  final String? attemptId;

  const AssessmentResult({
    required this.overallScore,
    required this.words,
    required this.overallFeedback,
    required this.recommendedPhonemeDrill,
    this.audioStorageUrl,
    this.attemptId,
  });

  factory AssessmentResult.fromJson(
    Map<String, dynamic> json, {
    String? audioUrl,
    String? attemptId,
  }) {
    return AssessmentResult(
      overallScore: (json['overall_score'] as num?)?.toInt() ?? 0,
      words: (json['words'] as List<dynamic>?)
              ?.map((w) => WordAssessment.fromJson(w as Map<String, dynamic>))
              .toList() ??
          [],
      overallFeedback: json['overall_feedback'] as String? ?? '',
      recommendedPhonemeDrill: json['recommended_phoneme_drill'] as String? ?? '',
      audioStorageUrl: audioUrl,
      attemptId: attemptId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'overall_score': overallScore,
      'words': words.map((w) => w.toJson()).toList(),
      'overall_feedback': overallFeedback,
      'recommended_phoneme_drill': recommendedPhonemeDrill,
    };
  }
}

