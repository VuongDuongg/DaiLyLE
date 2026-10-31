enum PhonemeStatus {
  correct,
  mispronounced,
  omitted,
  inserted;

  static PhonemeStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'correct':
        return PhonemeStatus.correct;
      case 'mispronounced':
        return PhonemeStatus.mispronounced;
      case 'omitted':
        return PhonemeStatus.omitted;
      case 'inserted':
        return PhonemeStatus.inserted;
      default:
        return PhonemeStatus.mispronounced;
    }
  }

  String toJson() => name;
}

class PhonemeComparison {
  final String expected;
  final String actual;
  final PhonemeStatus status;
  final int position;
  final String? tip;

  const PhonemeComparison({
    required this.expected,
    required this.actual,
    required this.status,
    required this.position,
    this.tip,
  });

  factory PhonemeComparison.fromJson(Map<String, dynamic> json) {
    return PhonemeComparison(
      expected: json['expected'] as String? ?? '',
      actual: json['actual'] as String? ?? '',
      status: PhonemeStatus.fromString(json['status'] as String? ?? 'mispronounced'),
      position: (json['position'] as num?)?.toInt() ?? 0,
      tip: json['tip'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expected': expected,
      'actual': actual,
      'status': status.toJson(),
      'position': position,
      'tip': tip,
    };
  }
}

class WordPhonemeDiff {
  final String word;
  final String expectedIpa;
  final String actualIpa;
  final double score;
  final List<PhonemeComparison> phonemes;

  const WordPhonemeDiff({
    required this.word,
    required this.expectedIpa,
    required this.actualIpa,
    required this.score,
    required this.phonemes,
  });

  factory WordPhonemeDiff.fromJson(Map<String, dynamic> json) {
    return WordPhonemeDiff(
      word: json['word'] as String? ?? '',
      expectedIpa: json['expected_ipa'] as String? ?? '',
      actualIpa: json['actual_ipa'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      phonemes: (json['phonemes'] as List<dynamic>?)
              ?.map((e) => PhonemeComparison.fromJson(e as Map<String, dynamic>))
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
      'phonemes': phonemes.map((p) => p.toJson()).toList(),
    };
  }
}

