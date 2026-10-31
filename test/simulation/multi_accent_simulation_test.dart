import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

class SimulationCase {
  final String userId;
  final String userName;
  final String accentProfile;
  final String sentenceText;
  final String standardIpa;
  final String simulatedSpokenIpa;
  final double expectedMinScore;
  final double expectedMaxScore;
  final double maxAllowedPer; // Max Phoneme Error Rate in %

  const SimulationCase({
    required this.userId,
    required this.userName,
    required this.accentProfile,
    required this.sentenceText,
    required this.standardIpa,
    required this.simulatedSpokenIpa,
    required this.expectedMinScore,
    required this.expectedMaxScore,
    required this.maxAllowedPer,
  });
}

class AlignmentResult {
  final int score;
  final double per; // Phoneme Error Rate (0 - 100%)
  final int substitutions;
  final int deletions;
  final int insertions;
  final int totalPhonemes;

  const AlignmentResult({
    required this.score,
    required this.per,
    required this.substitutions,
    required this.deletions,
    required this.insertions,
    required this.totalPhonemes,
  });
}

class PhonemeEvaluator {
  static AlignmentResult evaluate(String standardIpa, String actualIpa) {
    final cleanExp = standardIpa.replaceAll(RegExp(r'[\/ˈˌ. ]'), '').split('');
    final cleanAct = actualIpa.replaceAll(RegExp(r'[\/ˈˌ. ]'), '').split('');

    final n = cleanExp.length;
    final m = cleanAct.length;

    final dp = List.generate(n + 1, (_) => List.filled(m + 1, 0));
    for (int i = 0; i <= n; i++) dp[i][0] = i;
    for (int j = 0; j <= m; j++) dp[0][j] = j;

    for (int i = 1; i <= n; i++) {
      for (int j = 1; j <= m; j++) {
        final match = cleanExp[i - 1] == cleanAct[j - 1];
        dp[i][j] = [
          dp[i - 1][j - 1] + (match ? 0 : 1),
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
        ].reduce(math.min);
      }
    }

    // Backtrack to count exact errors
    int i = n;
    int j = m;
    int subs = 0;
    int dels = 0;
    int ins = 0;

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && dp[i][j] == dp[i - 1][j - 1] + (cleanExp[i - 1] == cleanAct[j - 1] ? 0 : 1)) {
        if (cleanExp[i - 1] != cleanAct[j - 1]) subs++;
        i--;
        j--;
      } else if (i > 0 && dp[i][j] == dp[i - 1][j] + 1) {
        dels++;
        i--;
      } else {
        ins++;
        j--;
      }
    }

    final totalErrors = subs + dels + ins;
    final totalPhonemes = math.max(n, 1);
    final per = (totalErrors / totalPhonemes) * 100.0;
    final score = math.max(0, 100 - per.round());

    return AlignmentResult(
      score: score,
      per: double.parse(per.toStringAsFixed(1)),
      substitutions: subs,
      deletions: dels,
      insertions: ins,
      totalPhonemes: n,
    );
  }
}

void main() {
  group('Multi-User & Multi-Accent AI Evaluation Simulation Suite', () {
    final testProfiles = [
      // Profile 1: Native General American Speaker
      const SimulationCase(
        userId: 'usr-us-001',
        userName: 'David Miller',
        accentProfile: 'Native General American (US)',
        sentenceText: 'Think through three thin things.',
        standardIpa: 'θɪŋk θruː θriː θɪn θɪŋz',
        simulatedSpokenIpa: 'θɪŋk θruː θriː θɪn θɪŋz',
        expectedMinScore: 95.0,
        expectedMaxScore: 100.0,
        maxAllowedPer: 5.0,
      ),

      // Profile 2: Native British (Received Pronunciation)
      const SimulationCase(
        userId: 'usr-uk-002',
        userName: 'Emma Watson',
        accentProfile: 'Native Received Pronunciation (UK)',
        sentenceText: 'Think through three thin things.',
        standardIpa: 'θɪŋk θruː θriː θɪn θɪŋz',
        simulatedSpokenIpa: 'θɪŋk θruː θriː θɪn θɪŋz',
        expectedMinScore: 90.0,
        expectedMaxScore: 100.0,
        maxAllowedPer: 8.0,
      ),

      // Profile 3: Vietnamese Learner - Final Consonants Omission (/k/, /z/, /t/ dropped)
      const SimulationCase(
        userId: 'usr-vn-003',
        userName: 'Nguyễn Văn An',
        accentProfile: 'Vietnamese Learner - Final Consonant Dropping',
        sentenceText: 'Think through three thin things.',
        standardIpa: 'θɪŋk θruː θriː θɪn θɪŋz',
        simulatedSpokenIpa: 'θɪŋ θruː θriː θɪn θɪŋ', // Dropped final /k/ and /z/
        expectedMinScore: 80.0,
        expectedMaxScore: 90.0,
        maxAllowedPer: 20.0,
      ),

      // Profile 4: Vietnamese Learner - Dental Fricatives Confusion (/θ/ -> /t/ or /s/)
      const SimulationCase(
        userId: 'usr-vn-004',
        userName: 'Trần Thị Mai',
        accentProfile: 'Vietnamese Learner - Dental Fricative Confusion (θ -> t)',
        sentenceText: 'Think through three thin things.',
        standardIpa: 'θɪŋk θruː θriː θɪn θɪŋz',
        simulatedSpokenIpa: 'tɪŋk truː triː tɪn tɪŋz', // Replaced all 5 /θ/ with /t/
        expectedMinScore: 65.0,
        expectedMaxScore: 80.0,
        maxAllowedPer: 30.0,
      ),

      // Profile 5: Vietnamese Learner - Severe Combined L1 Interference (/θ/ -> /t/ + dropped endings)
      const SimulationCase(
        userId: 'usr-vn-005',
        userName: 'Lê Hoàng Nam',
        accentProfile: 'Vietnamese Learner - Combined Severe Interference',
        sentenceText: 'Think through three thin things.',
        standardIpa: 'θɪŋk θruː θriː θɪn θɪŋz',
        simulatedSpokenIpa: 'tɪŋ tru tri tɪn tɪŋ', // Replaced /θ/ -> /t/, omitted /k/, /z/, short vowels
        expectedMinScore: 45.0,
        expectedMaxScore: 65.0,
        maxAllowedPer: 55.0,
      ),
    ];

    for (final testCase in testProfiles) {
      test('Simulation for ${testCase.userName} (${testCase.accentProfile})', () {
        final result = PhonemeEvaluator.evaluate(
          testCase.standardIpa,
          testCase.simulatedSpokenIpa,
        );

        // Verify score falls within expected physiological threshold
        expect(
          result.score.toDouble(),
          greaterThanOrEqualTo(testCase.expectedMinScore),
          reason: 'Score ${result.score} was below expected minimum ${testCase.expectedMinScore}',
        );
        expect(
          result.score.toDouble(),
          lessThanOrEqualTo(testCase.expectedMaxScore),
          reason: 'Score ${result.score} exceeded expected maximum ${testCase.expectedMaxScore}',
        );

        // Verify Phoneme Error Rate does not exceed bounds
        expect(
          result.per,
          lessThanOrEqualTo(testCase.maxAllowedPer),
          reason: 'PER ${result.per}% exceeded maximum allowed ${testCase.maxAllowedPer}%',
        );
      });
    }
  });
}

