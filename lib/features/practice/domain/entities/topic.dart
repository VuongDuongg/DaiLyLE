class Topic {
  final String id;
  final String nameEn;
  final String nameVi;
  final String iconName;
  final String? description;
  final int totalSentences;
  final int completedSentences;

  const Topic({
    required this.id,
    required this.nameEn,
    required this.nameVi,
    this.iconName = 'chat',
    this.description,
    this.totalSentences = 0,
    this.completedSentences = 0,
  });

  double get progressPercentage => totalSentences > 0
      ? (completedSentences / totalSentences).clamp(0.0, 1.0)
      : 0.0;

  factory Topic.fromJson(Map<String, dynamic> json, {int completed = 0}) {
    return Topic(
      id: json['id'] as String,
      nameEn: json['name_en'] as String? ?? '',
      nameVi: json['name_vi'] as String? ?? '',
      iconName: json['icon_name'] as String? ?? 'chat',
      description: json['description'] as String?,
      totalSentences: (json['total_sentences'] as num?)?.toInt() ?? 0,
      completedSentences: completed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_en': nameEn,
      'name_vi': nameVi,
      'icon_name': iconName,
      'description': description,
      'total_sentences': totalSentences,
    };
  }
}

