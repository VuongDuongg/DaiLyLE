class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final int dailyGoalMinutes;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastPracticeDate;
  final String reminderTime;
  final String timezone;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.dailyGoalMinutes = 15,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastPracticeDate,
    this.reminderTime = '20:00:00',
    this.timezone = 'Asia/Ho_Chi_Minh',
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      dailyGoalMinutes: (json['daily_goal_minutes'] as num?)?.toInt() ?? 15,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      lastPracticeDate: json['last_practice_date'] != null
          ? DateTime.tryParse(json['last_practice_date'] as String)
          : null,
      reminderTime: json['reminder_time'] as String? ?? '20:00:00',
      timezone: json['timezone'] as String? ?? 'Asia/Ho_Chi_Minh',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'daily_goal_minutes': dailyGoalMinutes,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_practice_date': lastPracticeDate?.toIso8601String().split('T').first,
      'reminder_time': reminderTime,
      'timezone': timezone,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

