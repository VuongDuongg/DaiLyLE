class PracticeSession {
  final String id;
  final String userId;
  final int durationSeconds;
  final DateTime practicedAt;
  final DateTime createdAt;

  const PracticeSession({
    required this.id,
    required this.userId,
    required this.durationSeconds,
    required this.practicedAt,
    required this.createdAt,
  });

  factory PracticeSession.fromJson(Map<String, dynamic> json) {
    return PracticeSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      durationSeconds: (json['duration_seconds'] as num).toInt(),
      practicedAt: DateTime.parse(json['practiced_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'duration_seconds': durationSeconds,
      'practiced_at': practicedAt.toUtc().toIso8601String(),
    };
  }
}

