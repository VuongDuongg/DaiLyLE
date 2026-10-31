class DisciplineStats {
  final int currentStreak;
  final int longestStreak;
  final int dailyGoalMinutes;
  final int todayMinutes;
  final bool isTodayCompleted;
  final String reminderTime;
  final List<bool> weeklyActiveDays; // 7 days: [Mon, Tue, Wed, Thu, Fri, Sat, Sun]

  const DisciplineStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.dailyGoalMinutes,
    required this.todayMinutes,
    required this.isTodayCompleted,
    required this.reminderTime,
    required this.weeklyActiveDays,
  });

  double get goalProgress => dailyGoalMinutes > 0
      ? (todayMinutes / dailyGoalMinutes).clamp(0.0, 1.0)
      : 0.0;

  factory DisciplineStats.fromJson(Map<String, dynamic> json) {
    List<bool> activeDays = [false, false, false, false, false, false, false];
    if (json['weekly_active_days'] is List) {
      activeDays = (json['weekly_active_days'] as List)
          .map((e) => e == true)
          .toList();
      while (activeDays.length < 7) {
        activeDays.add(false);
      }
    }

    return DisciplineStats(
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      dailyGoalMinutes: (json['daily_goal_minutes'] as num?)?.toInt() ?? 15,
      todayMinutes: (json['today_minutes'] as num?)?.toInt() ?? 0,
      isTodayCompleted: json['is_today_completed'] as bool? ?? false,
      reminderTime: json['reminder_time'] as String? ?? '20:00:00',
      weeklyActiveDays: activeDays,
    );
  }

  DisciplineStats copyWith({
    int? currentStreak,
    int? longestStreak,
    int? dailyGoalMinutes,
    int? todayMinutes,
    bool? isTodayCompleted,
    String? reminderTime,
    List<bool>? weeklyActiveDays,
  }) {
    return DisciplineStats(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      todayMinutes: todayMinutes ?? this.todayMinutes,
      isTodayCompleted: isTodayCompleted ?? this.isTodayCompleted,
      reminderTime: reminderTime ?? this.reminderTime,
      weeklyActiveDays: weeklyActiveDays ?? this.weeklyActiveDays,
    );
  }
}

