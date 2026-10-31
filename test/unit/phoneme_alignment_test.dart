import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:dailyle/features/pronunciation/domain/entities/assessment_result.dart';

/// Pure Dart implementation of Needleman-Wunsch Phoneme Alignment for unit testing
class PhonemeAlignmentEngine {
  static const Map<String, String> vietnameseTips = {
    'θ': 'Đặt đầu lưỡi giữa hai hàm răng và đẩy luồng hơi nhẹ ra ngoài, không phát âm thành /t/ hay /s/.',
    'ð': 'Đặt đầu lưỡi giữa hai hàm răng và rung dây thanh quản (hữu thanh), không phát âm thành /d/.',
    'ʃ': 'Tròn môi, đưa đầu lưỡi hơi lùi về sau và đẩy luồng hơi mạnh.',
    'æ': 'Mở rộng hàm dưới theo cả chiều dọc và ngang, phát âm bẹt miệng.',
  };

  static Map<String, dynamic> alignPhonemes(String expectedIpa, String actualIpa) {
    final cleanExp = expectedIpa.replaceAll(RegExp(r'[\/ˈˌ.]'), '');
    final cleanAct = actualIpa.replaceAll(RegExp(r'[\/ˈˌ.]'), '');

    final a = cleanExp.split('');
    final b = cleanAct.split('');
    final n = a.length;
    final m = b.length;

    if (n == 0 && m == 0) {
      return {'score': 100, 'items': <PhonemeAnalysisItem>[]};
    }

    // DP Matrix
    final dp = List.generate(n + 1, (_) => List.filled(m + 1, 0));
    for (int i = 0; i <= n; i++) dp[i][0] = i;
    for (int j = 0; j <= m; j++) dp[0][j] = j;

    for (int i = 1; i <= n; i++) {
      for (int j = 1; j <= m; j++) {
        final match = a[i - 1] == b[j - 1];
        final subCost = match ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j - 1] + subCost,
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
        ].reduce(math.min);
      }
    }

    // Backtracking
    int i = n;
    int j = m;
    final aligned = <PhonemeAnalysisItem>[];

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && dp[i][j] == dp[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)) {
        final expChar = a[i - 1];
        final actChar = b[j - 1];
        if (expChar == actChar) {
          aligned.insert(0, PhonemeAnalysisItem(phoneme: expChar, actual: actChar, status: 'correct'));
        } else {
          final tip = vietnameseTips[expChar] ?? 'Chú ý khẩu hình miệng cho âm này.';
          aligned.insert(0, PhonemeAnalysisItem(phoneme: expChar, actual: actChar, status: 'wrong', tip: tip));
        }
        i--;
        j--;
      } else if (i > 0 && dp[i][j] == dp[i - 1][j] + 1) {
        final expChar = a[i - 1];
        aligned.insert(0, PhonemeAnalysisItem(phoneme: expChar, actual: '-', status: 'missing', tip: 'Bị nuốt âm'));
        i--;
      } else {
        final actChar = b[j - 1];
        aligned.insert(0, PhonemeAnalysisItem(phoneme: '-', actual: actChar, status: 'extra'));
        j--;
      }
    }

    final maxLen = math.max(n, m);
    final distance = dp[n][m];
    final calculatedScore = maxLen > 0
        ? math.max(0, (((maxLen - distance) / maxLen) * 100).round())
        : 100;

    return {
      'score': calculatedScore,
      'items': aligned,
    };
  }
}

void main() {
  group('Phoneme Alignment & Scoring Tests', () {
    test('Perfect Match: standard /θɪŋk/ vs actual /θɪŋk/ should score 100%', () {
      final result = PhonemeAlignmentEngine.alignPhonemes('θɪŋk', 'θɪŋk');
      final score = result['score'] as int;
      final items = result['items'] as List<PhonemeAnalysisItem>;

      expect(score, equals(100));
      expect(items.length, equals(4));
      expect(items.every((item) => item.isCorrect), isTrue);
    });

    test('Substitution: Vietnamese learner saying /tɪŋk/ instead of /θɪŋk/', () {
      final result = PhonemeAlignmentEngine.alignPhonemes('θɪŋk', 'tɪŋk');
      final score = result['score'] as int;
      final items = result['items'] as List<PhonemeAnalysisItem>;

      expect(score, equals(75)); // 3 matches out of 4 phonemes = 75%
      expect(items[0].phoneme, equals('θ'));
      expect(items[0].actual, equals('t'));
      expect(items[0].status, equals('wrong'));
      expect(items[0].tip, contains('Đặt đầu lưỡi giữa hai hàm răng'));

      // The remaining 3 phonemes are correct
      expect(items[1].isCorrect, isTrue); // ɪ
      expect(items[2].isCorrect, isTrue); // ŋ
      expect(items[3].isCorrect, isTrue); // k
    });

    test('Ending Sound Omission: Vietnamese learner dropping final /k/ in /θɪŋk/', () {
      final result = PhonemeAlignmentEngine.alignPhonemes('θɪŋk', 'θɪŋ');
      final score = result['score'] as int;
      final items = result['items'] as List<PhonemeAnalysisItem>;

      expect(score, equals(75)); // 3 out of 4 phonemes
      final lastItem = items.last;
      expect(lastItem.phoneme, equals('k'));
      expect(lastItem.actual, equals('-'));
      expect(lastItem.isMissing, isTrue);
    });

    test('Multiple Errors: Severe mispronunciation /tɪn/ vs /θɪŋk/', () {
      final result = PhonemeAlignmentEngine.alignPhonemes('θɪŋk', 'tɪn');
      final score = result['score'] as int;

      // 2 errors (θ -> t, ŋk -> n): score should drop below 60%
      expect(score, lessThan(60));
    });

    test('Empty edge case returns 100% without crashing', () {
      final result = PhonemeAlignmentEngine.alignPhonemes('', '');
      expect(result['score'], equals(100));
    });
  });
}

