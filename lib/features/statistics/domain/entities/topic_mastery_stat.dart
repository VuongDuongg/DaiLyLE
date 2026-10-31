class TopicMasteryStat {
  final String topicId;
  final String topicName;
  final String iconName;
  final int averageScore;
  final int completedCount;
  final int totalCount;

  const TopicMasteryStat({
    required this.topicId,
    required this.topicName,
    required this.iconName,
    required this.averageScore,
    required this.completedCount,
    required this.totalCount,
  });

  double get progress => totalCount > 0
      ? (completedCount / totalCount).clamp(0.0, 1.0)
      : 0.0;
}

class WeakPhonemeStat {
  final String phoneme;
  final int errorCount;
  final String exampleWord;
  final String tipVi;

  const WeakPhonemeStat({
    required this.phoneme,
    required this.errorCount,
    required this.exampleWord,
    required this.tipVi,
  });
}

