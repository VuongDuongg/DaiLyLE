import 'package:flutter_test/flutter_test.dart';

/// Pure Dart reproduction of the PostgreSQL `update_user_streak` trigger logic
class StreakCalculator {
  static Map<String, dynamic> evaluateSession({
    required DateTime? lastPracticeDate,
    required int currentStreak,
    required int longestStreak,
    required DateTime practicedAtUtc,
    required String timezone,
  }) {
    // 1. Resolve local calendar date using timezone offset
    // Simulated offset: 'Asia/Ho_Chi_Minh' is UTC+7, 'America/New_York' is UTC-5
    final offsetHours = timezone == 'Asia/Ho_Chi_Minh'
        ? 7
        : timezone == 'America/New_York'
            ? -5
            : 0;

    final localDateTime = practicedAtUtc.add(Duration(hours: offsetHours));
    final localPracticeDate = DateTime(
      localDateTime.year,
      localDateTime.month,
      localDateTime.day,
    );

    int updatedCurrent = currentStreak;
    int updatedLongest = longestStreak;
    DateTime updatedLastDate = localPracticeDate;

    if (lastPracticeDate == null) {
      // First practice ever
      updatedCurrent = 1;
      updatedLongest = updatedLongest > 1 ? updatedLongest : 1;
    } else {
      final lastDateOnly = DateTime(
        lastPracticeDate.year,
        lastPracticeDate.month,
        lastPracticeDate.day,
      );

      final differenceInDays = localPracticeDate.difference(lastDateOnly).inDays;

      if (differenceInDays == 0) {
        // Practiced twice on the same local calendar day: NO CHANGE
        return {
          'current_streak': currentStreak,
          'longest_streak': longestStreak,
          'last_practice_date': lastDateOnly,
        };
      } else if (differenceInDays == 1) {
        // Exact consecutive day: Streak increment!
        updatedCurrent = currentStreak + 1;
        if (updatedCurrent > updatedLongest) {
          updatedLongest = updatedCurrent;
        }
      } else if (differenceInDays > 1) {
        // Missed 1 or more days: Streak resets to 1
        updatedCurrent = 1;
      } else {
        // Out-of-order offline sync (differenceInDays < 0): preserve existing state
        return {
          'current_streak': currentStreak,
          'longest_streak': longestStreak,
          'last_practice_date': lastDateOnly,
        };
      }
    }

    return {
      'current_streak': updatedCurrent,
      'longest_streak': updatedLongest,
      'last_practice_date': updatedLastDate,
    };
  }
}

void main() {
  group('Discipline & Streak Engine Logic Tests', () {
    const tz = 'Asia/Ho_Chi_Minh';

    test('Case 1: User practices for the very first time', () {
      final res = StreakCalculator.evaluateSession(
        lastPracticeDate: null,
        currentStreak: 0,
        longestStreak: 0,
        practicedAtUtc: DateTime.utc(2026, 10, 31, 2, 0), // 09:00 AM local
        timezone: tz,
      );

      expect(res['current_streak'], equals(1));
      expect(res['longest_streak'], equals(1));
      expect(res['last_practice_date'], equals(DateTime(2026, 10, 31)));
    });

    test('Case 2: User practices twice on the same day (No double increment)', () {
      // First session at 08:00 AM
      final first = StreakCalculator.evaluateSession(
        lastPracticeDate: null,
        currentStreak: 0,
        longestStreak: 0,
        practicedAtUtc: DateTime.utc(2026, 10, 31, 1, 0),
        timezone: tz,
      );

      // Second session at 20:00 PM on the same local day
      final second = StreakCalculator.evaluateSession(
        lastPracticeDate: first['last_practice_date'] as DateTime,
        currentStreak: first['current_streak'] as int,
        longestStreak: first['longest_streak'] as int,
        practicedAtUtc: DateTime.utc(2026, 10, 31, 13, 0),
        timezone: tz,
      );

      expect(second['current_streak'], equals(1)); // Should remain 1
      expect(second['longest_streak'], equals(1));
    });

    test('Case 3: User practices on consecutive days (Streak progresses)', () {
      final day1 = StreakCalculator.evaluateSession(
        lastPracticeDate: null,
        currentStreak: 0,
        longestStreak: 0,
        practicedAtUtc: DateTime.utc(2026, 10, 30, 3, 0),
        timezone: tz,
      );

      final day2 = StreakCalculator.evaluateSession(
        lastPracticeDate: day1['last_practice_date'] as DateTime,
        currentStreak: day1['current_streak'] as int,
        longestStreak: day1['longest_streak'] as int,
        practicedAtUtc: DateTime.utc(2026, 10, 31, 3, 0),
        timezone: tz,
      );

      expect(day2['current_streak'], equals(2));
      expect(day2['longest_streak'], equals(2));
    });

    test('Case 4: User misses a day (Streak resets to 1, Longest streak preserved)', () {
      // User had a 5-day streak ending on Oct 25
      final res = StreakCalculator.evaluateSession(
        lastPracticeDate: DateTime(2026, 10, 25),
        currentStreak: 5,
        longestStreak: 10,
        practicedAtUtc: DateTime.utc(2026, 10, 31, 5, 0), // Jumped to Oct 31 (missed 6 days)
        timezone: tz,
      );

      expect(res['current_streak'], equals(1)); // Reset to 1
      expect(res['longest_streak'], equals(10)); // Preserved personal record!
    });

    test('Case 5: Crossing Midnight & Timezone Boundary (00:30 AM local is 17:30 UTC previous day)', () {
      // 00:30 AM Hanoi on Nov 1 is 17:30 UTC on Oct 31
      final lateNightUtc = DateTime.utc(2026, 10, 31, 17, 30);

      final res = StreakCalculator.evaluateSession(
        lastPracticeDate: DateTime(2026, 10, 31),
        currentStreak: 3,
        longestStreak: 5,
        practicedAtUtc: lateNightUtc, // Converted to 2026-11-01 in Asia/Ho_Chi_Minh
        timezone: tz,
      );

      // Even though UTC is 2026-10-31, local date is 2026-11-01, exactly consecutive!
      expect(res['last_practice_date'], equals(DateTime(2026, 11, 1)));
      expect(res['current_streak'], equals(4));
    });

    test('Case 6: Out-of-order offline sync does not corrupt existing streak', () {
      final res = StreakCalculator.evaluateSession(
        lastPracticeDate: DateTime(2026, 10, 31),
        currentStreak: 7,
        longestStreak: 7,
        practicedAtUtc: DateTime.utc(2026, 10, 28, 5, 0), // Older offline session synced today
        timezone: tz,
      );

      expect(res['current_streak'], equals(7)); // Remains 7, no regression
    });
  });
}

