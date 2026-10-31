import 'package:flutter/material.dart';
import '../../domain/entities/topic_mastery_stat.dart';

class TopicMasteryCard extends StatelessWidget {
  final List<TopicMasteryStat> topics;

  const TopicMasteryCard({
    super.key,
    required this.topics,
  });

  IconData _getTopicIcon(String iconName) {
    switch (iconName) {
      case 'waving_hand':
        return Icons.waving_hand_rounded;
      case 'local_cafe':
        return Icons.local_cafe_rounded;
      case 'explore':
        return Icons.explore_rounded;
      case 'business_center':
        return Icons.business_center_rounded;
      default:
        return Icons.chat_bubble_rounded;
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green.shade600;
    if (score >= 60) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mức độ thành thạo theo chủ đề',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(Icons.insights_rounded, size: 20),
            ],
          ),
          const SizedBox(height: 16),

          ...topics.map((t) {
            final scoreColor = _getScoreColor(t.averageScore);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: scoreColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getTopicIcon(t.iconName),
                          size: 18,
                          color: scoreColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.topicName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Đã luyện ${t.completedCount}/${t.totalCount} câu',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scoreColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${t.averageScore}%',
                          style: TextStyle(
                            color: scoreColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: t.progress,
                      minHeight: 5,
                      backgroundColor: theme.colorScheme.outlineVariant.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

