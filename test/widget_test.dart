import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailyle/features/discipline/presentation/widgets/streak_header_card.dart';
import 'package:dailyle/features/pronunciation/domain/entities/assessment_result.dart';
import 'package:dailyle/features/pronunciation/presentation/widgets/rich_phoneme_text.dart';

void main() {
  testWidgets('StreakHeaderCard renders streak flame and goal progress',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StreakHeaderCard(
            currentStreak: 7,
            longestStreak: 15,
            todayMinutes: 12,
            dailyGoalMinutes: 15,
          ),
        ),
      ),
    );

    // Verify streak count and record badge
    expect(find.text('7 Ngày'), findsOneWidget);
    expect(find.text('Kỷ lục: 15'), findsOneWidget);
    expect(find.textContaining('12 / 15 phút'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
  });

  testWidgets('RichPhonemeText renders color-coded words and phonemes',
      (WidgetTester tester) async {
    const sampleWords = [
      WordAssessment(
        word: 'think',
        expectedIpa: 'θɪŋk',
        actualIpa: 'tɪŋk',
        score: 75,
        phonemeAnalysis: [
          PhonemeAnalysisItem(
            phoneme: 'θ',
            actual: 't',
            status: 'wrong',
            tip: 'Đặt đầu lưỡi giữa hai hàm răng',
          ),
          PhonemeAnalysisItem(
            phoneme: 'ɪ',
            actual: 'ɪ',
            status: 'correct',
          ),
          PhonemeAnalysisItem(
            phoneme: 'ŋ',
            actual: 'ŋ',
            status: 'correct',
          ),
          PhonemeAnalysisItem(
            phoneme: 'k',
            actual: 'k',
            status: 'correct',
          ),
        ],
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RichPhonemeText(words: sampleWords),
        ),
      ),
    );

    // Verify word and RichText are rendered
    expect(find.text('think'), findsOneWidget);
    expect(find.byType(RichText), findsWidgets);
  });
}
