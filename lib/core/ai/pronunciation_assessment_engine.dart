import 'dart:math';
import '../audio/speech_recorder_service.dart';
import '../../features/pronunciation/domain/entities/assessment_result.dart';

class PronunciationAssessmentEngine {
  static final PronunciationAssessmentEngine _instance =
      PronunciationAssessmentEngine._internal();
  factory PronunciationAssessmentEngine() => _instance;
  PronunciationAssessmentEngine._internal();

  /// Comprehensive Vietnamese phonetic guidance for common English pronunciation pitfalls
  static const Map<String, String> vietnameseTips = {
    'θ':
        'Đặt đầu lưỡi giữa hai hàm răng và đẩy luồng hơi nhẹ ra ngoài, không phát âm thành /t/ hay /s/. (Ví dụ: "think", "three")',
    'ð':
        'Đặt đầu lưỡi giữa hai hàm răng và rung thanh quản (hữu thanh), không phát âm thành /d/. (Ví dụ: "this", "mother")',
    'ʃ':
        'Tròn môi, đưa đầu lưỡi hơi lùi về sau và đẩy luồng hơi mạnh dứt khoát. (Ví dụ: "she", "action")',
    'ʒ':
        'Khẩu hình giống âm /ʃ/ nhưng rung dây thanh quản sâu từ cổ họng. (Ví dụ: "vision", "measure")',
    'tʃ':
        'Bật nhẹ âm /t/ rồi chu môi chuyển nhanh sang âm /ʃ/ dứt khoát. (Ví dụ: "chair", "beach")',
    'dʒ':
        'Khẩu hình như /tʃ/ nhưng phát âm hữu thanh và rung cổ họng. (Ví dụ: "job", "large")',
    'æ':
        'Mở rộng hàm dưới theo cả chiều dọc và ngang, phát âm bẹt miệng. (Ví dụ: "cat", "have")',
    'ʌ':
        'Hạ thấp hàm, thả lỏng môi và phát âm dứt khoát ngắn gọn. (Ví dụ: "cut", "cup")',
    'iː':
        'Cười nhẹ, kéo căng khóe môi sang hai bên và kéo dài âm hơn. (Ví dụ: "see", "meet")',
    'uː':
        'Chu tròn môi về phía trước và ngân dài âm /uː/. (Ví dụ: "blue", "food")',
    'ɔː':
        'Mở tròn khẩu hình miệng và phát âm sâu từ vòm họng. (Ví dụ: "thought", "call")',
    'ŋ':
        'Nâng cuống lưỡi chạm ngạc mềm, thở luồng hơi thoát ra qua mũi. (Ví dụ: "sing", "morning")',
    'r':
        'Uốn cong đầu lưỡi về phía vòm họng trên nhưng không chạm vào vòm miệng. (Ví dụ: "right", "red")',
    's':
        'Bật rõ âm gió /s/ xát răng ở cuối từ, tránh thói quen nuốt phụ âm cuối. (Ví dụ: "yes", "nice")',
    't':
        'Chặn luồng hơi bằng đầu lưỡi chạm ngạc trên rồi bật nhẹ âm /t/ dứt khoát. (Ví dụ: "meet", "get")',
    'd':
        'Đầu lưỡi chạm ngạc trên, bật âm dứt khoát và rung nhẹ thanh quản. (Ví dụ: "good", "need")',
    'k':
        'Nâng cuống lưỡi chặn luồng hơi rồi bật mạnh âm /k/ từ cổ họng. (Ví dụ: "think", "like")',
    'default_missing':
        'Bạn đã nuốt âm đuôi (ending sound) này. Người Việt thường có thói quen bỏ quên phụ âm cuối.',
    'default_wrong':
        'Khẩu hình miệng chưa chuẩn xác cho âm này. Hãy nghe mẫu và điều chỉnh vị trí đặt lưỡi/môi.',
  };

  /// Common conversational G2P (word to standard IPA) lookup dictionary
  static const Map<String, String> g2pDict = {
    'good': 'ɡʊd',
    'morning': 'ˈmɔːr.nɪŋ',
    'how': 'haʊ',
    'are': 'ɑːr',
    'you': 'juː',
    'today': 'təˈdeɪ',
    'nice': 'naɪs',
    'to': 'tuː',
    'meet': 'miːt',
    'my': 'maɪ',
    'name': 'neɪm',
    'is': 'ɪz',
    'alex': 'ˈæl.ɪks',
    'have': 'hæv',
    'a': 'ə',
    'wonderful': 'ˈwʌn.dər.fəl',
    'weekend': 'ˈwiːk.ɛnd',
    'ahead': 'əˈhɛd',
    'where': 'wɛər',
    'from': 'frʌm',
    'i': 'aɪ',
    'am': 'æm',
    'originally': 'əˈrɪdʒ.ən.əl.i',
    'vietnam': 'ˌvjɛtˈnæm',
    'thank': 'θæŋk',
    'so': 'soʊ',
    'much': 'mʌtʃ',
    'for': 'fɔːr',
    'your': 'jʊər',
    'help': 'hɛlp',
    'excuse': 'ɪkˈskjuːz',
    'me': 'miː',
    'can': 'kæn',
    'tell': 'tɛl',
    'way': 'weɪ',
    'station': 'ˈsteɪ.ʃən',
    'straight': 'streɪt',
    'and': 'ænd',
    'turn': 'tɜːrn',
    'left': 'lɛft',
    'at': 'æt',
    'the': 'ðə',
    'first': 'fɜːrst',
    'corner': 'ˈkɔːr.nər',
    'think': 'θɪŋk',
    'through': 'θruː',
    'three': 'θriː',
    'thin': 'θɪn',
    'things': 'θɪŋz',
  };

  /// Main AI assessment method combining Acoustic, Speech-to-Text, and Needleman-Wunsch Alignment
  AssessmentResult evaluate({
    required RecordedAudioResult audioResult,
    required String targetSentence,
    required String standardIpa,
    String? recognizedText,
  }) {
    // 1. ACOUSTIC DURATION & SILENCE CHECK
    final durationMs = audioResult.durationMs;
    final bytesLength = audioResult.bytes.length;

    // If recording is excessively short (< 450ms) or byte count is negligible (< 1000 bytes)
    if (durationMs < 450 || bytesLength < 1000) {
      return _buildEmptyAudioResult(targetSentence, standardIpa);
    }

    // 2. PARSE TARGET WORDS & IPA TOKENS
    final targetWords = targetSentence.trim().split(RegExp(r'\s+'));
    final ipaTokens =
        standardIpa.replaceAll('/', '').trim().split(RegExp(r'\s+'));

    // 3. NORMALIZE RECOGNIZED TEXT
    final cleanRecognized = recognizedText != null ? recognizedText.trim() : '';
    final recognizedWords = cleanRecognized.isNotEmpty
        ? cleanRecognized
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), '')
            .trim()
            .split(RegExp(r'\s+'))
        : <String>[];

    // If NO recognizable English speech was detected (user spoke gibberish, spoke Vietnamese, blew into mic, etc.)
    if (recognizedWords.isEmpty) {
      return _buildUnrecognizedSpeechResult(
        targetSentence,
        standardIpa,
        userSpokenText: cleanRecognized.isNotEmpty ? cleanRecognized : null,
      );
    }

    final List<WordAssessment> evaluatedWords = [];
    int totalWordScore = 0;
    int matchedWordsCount = 0;
    final Map<String, int> phonemeErrorFrequency = {};

    // 4. EVALUATE EACH TARGET WORD WITH NEEDLEMAN-WUNSCH ALIGNMENT
    for (int i = 0; i < targetWords.length; i++) {
      final rawWord = targetWords[i];
      final cleanWord = rawWord.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      final expIpa = i < ipaTokens.length
          ? ipaTokens[i]
          : (g2pDict[cleanWord] ?? cleanWord);

      final matchResult = _findBestMatchInRecognized(
        targetWord: cleanWord,
        expectedIpa: expIpa,
        recognizedWords: recognizedWords,
        wordIndex: i,
        totalTargetWords: targetWords.length,
      );

      if (!matchResult.isMissing) {
        matchedWordsCount++;
        final alignment = alignPhonemesNeedlemanWunsch(
          expIpa,
          matchResult.actualIpa,
        );

        for (final item in alignment.phonemeAnalysis) {
          if (item.status == 'wrong' || item.status == 'missing') {
            phonemeErrorFrequency[item.phoneme] =
                (phonemeErrorFrequency[item.phoneme] ?? 0) + 1;
          }
        }

        final finalWordScore =
            (alignment.score * matchResult.confidenceMultiplier).round().clamp(0, 100);

        totalWordScore += finalWordScore;
        evaluatedWords.add(WordAssessment(
          word: rawWord,
          expectedIpa: expIpa,
          actualIpa: matchResult.actualIpa,
          score: finalWordScore,
          phonemeAnalysis: alignment.phonemeAnalysis,
        ));
      } else {
        // Target word was NOT spoken by the user (or spoken completely wrong/gibberish)
        final cleanExp = expIpa.replaceAll(RegExp(r'[\/ˈˌ.]'), '');
        final phonemes = cleanExp.split('').map((char) {
          return PhonemeAnalysisItem(
            phoneme: char,
            actual: '-',
            status: 'missing',
            tip: vietnameseTips[char] ?? vietnameseTips['default_missing'],
          );
        }).toList();

        final firstPhoneme = cleanExp.isNotEmpty ? cleanExp[0] : 'θ';
        phonemeErrorFrequency[firstPhoneme] =
            (phonemeErrorFrequency[firstPhoneme] ?? 0) + 1;

        evaluatedWords.add(WordAssessment(
          word: rawWord,
          expectedIpa: expIpa,
          actualIpa: '-',
          score: 0,
          phonemeAnalysis: phonemes,
        ));
      }
    }

    // 5. CALCULATE OVERALL SCORE
    int finalOverallScore = 0;
    if (matchedWordsCount == 0) {
      // User spoke English words, but NONE matched the target sentence
      finalOverallScore = 10;
    } else {
      final rawAverage = (totalWordScore / targetWords.length).round();
      final minExpectedDuration = targetWords.length * 280;
      double pacingMultiplier = 1.0;
      if (durationMs < minExpectedDuration) {
        pacingMultiplier = (durationMs / minExpectedDuration).clamp(0.5, 0.95);
      }
      finalOverallScore = (rawAverage * pacingMultiplier).round().clamp(0, 100);
    }

    // 6. IDENTIFY WEAKEST PHONEME FOR DRILL
    String recommendedDrill = '/θ/';
    if (phonemeErrorFrequency.isNotEmpty) {
      final sortedErrors = phonemeErrorFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      recommendedDrill = '/${sortedErrors.first.key}/';
    }

    // 7. CONSTRUCT VIETNAMESE FEEDBACK
    final feedback = _generateVietnameseFeedback(
      overallScore: finalOverallScore,
      matchedCount: matchedWordsCount,
      targetCount: targetWords.length,
      userSpokenText: cleanRecognized,
      recommendedDrill: recommendedDrill,
    );

    return AssessmentResult(
      overallScore: finalOverallScore,
      words: evaluatedWords,
      overallFeedback: feedback,
      recommendedPhonemeDrill: recommendedDrill,
    );
  }

  /// Needleman-Wunsch Dynamic Programming alignment for phonetic sequences
  PhonemeAlignmentResult alignPhonemesNeedlemanWunsch(
    String expectedIpa,
    String actualIpa,
  ) {
    final cleanExp = expectedIpa.replaceAll(RegExp(r'[\/ˈˌ.]'), '');
    final cleanAct = actualIpa.replaceAll(RegExp(r'[\/ˈˌ.]'), '');

    final a = cleanExp.split('');
    final b = cleanAct.split('');
    final n = a.length;
    final m = b.length;

    if (n == 0 && m == 0) {
      return const PhonemeAlignmentResult(phonemeAnalysis: [], score: 100);
    }
    if (m == 0) {
      final items = a.map((char) {
        final tip = vietnameseTips[char] ?? vietnameseTips['default_missing']!;
        return PhonemeAnalysisItem(
          phoneme: char,
          actual: '-',
          status: 'missing',
          tip: tip,
        );
      }).toList();
      return PhonemeAlignmentResult(phonemeAnalysis: items, score: 0);
    }

    // Cost matrix initialization
    final dp = List.generate(n + 1, (_) => List.filled(m + 1, 0));
    for (int i = 0; i <= n; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= m; j++) {
      dp[0][j] = j;
    }

    // Fill DP Matrix
    for (int i = 1; i <= n; i++) {
      for (int j = 1; j <= m; j++) {
        final match = a[i - 1] == b[j - 1];
        final subCost = match ? 0 : 1;
        dp[i][j] = min(
          dp[i - 1][j - 1] + subCost,
          min(
            dp[i - 1][j] + 1,
            dp[i][j - 1] + 1,
          ),
        );
      }
    }

    // Backtrack alignment path
    int i = n;
    int j = m;
    final List<PhonemeAnalysisItem> aligned = [];

    while (i > 0 || j > 0) {
      if (i > 0 &&
          j > 0 &&
          dp[i][j] == dp[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)) {
        final expChar = a[i - 1];
        final actChar = b[j - 1];

        if (expChar == actChar) {
          aligned.insert(
            0,
            PhonemeAnalysisItem(
              phoneme: expChar,
              actual: actChar,
              status: 'correct',
            ),
          );
        } else {
          final tip = vietnameseTips[expChar] ?? vietnameseTips['default_wrong']!;
          aligned.insert(
            0,
            PhonemeAnalysisItem(
              phoneme: expChar,
              actual: actChar,
              status: 'wrong',
              tip: tip,
            ),
          );
        }
        i--;
        j--;
      } else if (i > 0 && dp[i][j] == dp[i - 1][j] + 1) {
        final expChar = a[i - 1];
        final tip = vietnameseTips[expChar] ?? vietnameseTips['default_missing']!;
        aligned.insert(
          0,
          PhonemeAnalysisItem(
            phoneme: expChar,
            actual: '-',
            status: 'missing',
            tip: tip,
          ),
        );
        i--;
      } else {
        final actChar = b[j - 1];
        aligned.insert(
          0,
          PhonemeAnalysisItem(
            phoneme: '-',
            actual: actChar,
            status: 'extra',
          ),
        );
        j--;
      }
    }

    final maxLen = max(n, m);
    final distance = dp[n][m];
    final score = maxLen > 0
        ? max(0, (((maxLen - distance) / maxLen) * 100).round())
        : 100;

    return PhonemeAlignmentResult(
      phonemeAnalysis: aligned,
      score: score,
    );
  }

  /// Maps user spoken words to target words with strict fuzzy alignment
  _WordMatchResult _findBestMatchInRecognized({
    required String targetWord,
    required String expectedIpa,
    required List<String> recognizedWords,
    required int wordIndex,
    required int totalTargetWords,
  }) {
    // 1. Exact match in full transcript
    if (recognizedWords.contains(targetWord)) {
      return _WordMatchResult(
        actualIpa: expectedIpa,
        confidenceMultiplier: 1.0,
        isMissing: false,
      );
    }

    // 2. Positional window search (within +/- 2 words)
    final startIdx = max(0, wordIndex - 1);
    final endIdx = min(recognizedWords.length, wordIndex + 2);

    for (int k = startIdx; k < endIdx; k++) {
      final recWord = recognizedWords[k];
      final dist = _levenshteinDistance(targetWord, recWord);
      final similarity = 1.0 - (dist / max(targetWord.length, recWord.length));

      // Strict threshold: At least 70% character similarity to count as a distorted pronunciation
      if (similarity >= 0.70) {
        final actualIpa = g2pDict[recWord] ?? _heuristicWordToIpa(recWord);
        return _WordMatchResult(
          actualIpa: actualIpa,
          confidenceMultiplier: similarity,
          isMissing: false,
        );
      }
    }

    // 3. Check known Vietnamese phonetic pitfalls (e.g. "think" -> "tink", "this" -> "dis")
    if (targetWord == 'think' && recognizedWords.contains('tink')) {
      return const _WordMatchResult(
        actualIpa: 'tɪŋk',
        confidenceMultiplier: 0.70,
        isMissing: false,
      );
    }
    if (targetWord == 'three' && (recognizedWords.contains('tree') || recognizedWords.contains('free'))) {
      return const _WordMatchResult(
        actualIpa: 'triː',
        confidenceMultiplier: 0.70,
        isMissing: false,
      );
    }
    if (targetWord == 'this' && recognizedWords.contains('dis')) {
      return const _WordMatchResult(
        actualIpa: 'dɪs',
        confidenceMultiplier: 0.70,
        isMissing: false,
      );
    }

    // Completely missing or spoken gibberish
    return const _WordMatchResult(
      actualIpa: '',
      confidenceMultiplier: 0.0,
      isMissing: true,
    );
  }

  AssessmentResult _buildEmptyAudioResult(String sentence, String standardIpa) {
    final words = sentence.trim().split(RegExp(r'\s+'));
    final ipaTokens = standardIpa.replaceAll('/', '').trim().split(RegExp(r'\s+'));

    final List<WordAssessment> wordList = [];
    for (int i = 0; i < words.length; i++) {
      final rawWord = words[i];
      final expIpa = i < ipaTokens.length ? ipaTokens[i] : rawWord;
      final cleanExp = expIpa.replaceAll(RegExp(r'[\/ˈˌ.]'), '');

      final phonemes = cleanExp.split('').map((char) {
        return PhonemeAnalysisItem(
          phoneme: char,
          actual: '-',
          status: 'missing',
          tip: vietnameseTips[char] ?? vietnameseTips['default_missing'],
        );
      }).toList();

      wordList.add(WordAssessment(
        word: rawWord,
        expectedIpa: expIpa,
        actualIpa: '-',
        score: 0,
        phonemeAnalysis: phonemes,
      ));
    }

    return AssessmentResult(
      overallScore: 12,
      words: wordList,
      overallFeedback:
          'Không phát hiện thấy tiếng nói rõ ràng trong bản ghi âm (dưới 0.5s). Vui lòng nhấn giữ mic và phát âm to, rõ ràng cả câu tiếng Anh.',
      recommendedPhonemeDrill: '/θ/',
    );
  }

  AssessmentResult _buildUnrecognizedSpeechResult(
    String sentence,
    String standardIpa, {
    String? userSpokenText,
  }) {
    final words = sentence.trim().split(RegExp(r'\s+'));
    final ipaTokens = standardIpa.replaceAll('/', '').trim().split(RegExp(r'\s+'));

    final List<WordAssessment> wordList = [];
    for (int i = 0; i < words.length; i++) {
      final rawWord = words[i];
      final expIpa = i < ipaTokens.length ? ipaTokens[i] : rawWord;
      final cleanExp = expIpa.replaceAll(RegExp(r'[\/ˈˌ.]'), '');

      final phonemes = cleanExp.split('').map((char) {
        return PhonemeAnalysisItem(
          phoneme: char,
          actual: '-',
          status: 'missing',
          tip: vietnameseTips[char] ?? vietnameseTips['default_missing'],
        );
      }).toList();

      wordList.add(WordAssessment(
        word: rawWord,
        expectedIpa: expIpa,
        actualIpa: '-',
        score: 0,
        phonemeAnalysis: phonemes,
      ));
    }

    final feedback = (userSpokenText != null && userSpokenText.trim().isNotEmpty)
        ? 'AI nhận diện được: "$userSpokenText". Giọng nói không khớp với câu mẫu tiếng Anh. Vui lòng nghe lại câu mẫu và phát âm đúng các từ.'
        : 'AI không nhận diện được từ tiếng Anh nào trong giọng nói của bạn (có thể do nói từ ngữ ngoài bài, nói tiếng Việt, hoặc phát âm chưa rõ). Vui lòng nghe mẫu và phát âm lại câu tiếng Anh.';

    return AssessmentResult(
      overallScore: 15,
      words: wordList,
      overallFeedback: feedback,
      recommendedPhonemeDrill: '/θ/',
    );
  }

  String _generateVietnameseFeedback({
    required int overallScore,
    required int matchedCount,
    required int targetCount,
    required String userSpokenText,
    required String recommendedDrill,
  }) {
    if (matchedCount == 0) {
      return 'AI nhận diện được: "$userSpokenText". Không có từ nào khớp với câu mẫu tiếng Anh. Vui lòng nghe lại mẫu câu và đọc đúng từng từ.';
    } else if (matchedCount < targetCount) {
      return 'Bạn mới chỉ phát âm được $matchedCount/$targetCount từ trong câu. Hãy nghe lại câu mẫu và luyện phát âm đầy đủ tất cả các từ nhé!';
    } else if (overallScore >= 90) {
      return 'Phát âm rất xuất sắc! Ngữ điệu tự nhiên, các âm tiết rõ ràng, chuẩn ngữ âm bản xứ.';
    } else if (overallScore >= 75) {
      return 'Phát âm khá tốt! Bạn nói rõ câu, tuy nhiên hãy chú ý thêm các phụ âm xát hoặc âm đuôi $recommendedDrill để câu mượt mà hơn.';
    } else {
      return 'Bạn đã nói đủ các từ, nhưng khẩu hình một số âm chưa chuẩn (chú ý các âm đỏ bên dưới). Bấm vào từng từ để xem hướng dẫn đặt lưỡi/môi nhé.';
    }
  }

  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[s2.length];
  }

  String _heuristicWordToIpa(String word) {
    return word
        .replaceAll('th', 'θ')
        .replaceAll('sh', 'ʃ')
        .replaceAll('ch', 'tʃ')
        .replaceAll('ee', 'iː')
        .replaceAll('oo', 'uː');
  }
}

class PhonemeAlignmentResult {
  final List<PhonemeAnalysisItem> phonemeAnalysis;
  final int score;

  const PhonemeAlignmentResult({
    required this.phonemeAnalysis,
    required this.score,
  });
}

class _WordMatchResult {
  final String actualIpa;
  final double confidenceMultiplier;
  final bool isMissing;

  const _WordMatchResult({
    required this.actualIpa,
    required this.confidenceMultiplier,
    required this.isMissing,
  });
}
