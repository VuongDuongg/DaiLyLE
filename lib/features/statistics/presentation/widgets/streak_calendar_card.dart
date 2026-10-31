import 'package:flutter/material.dart';
import '../../domain/entities/discipline_stats.dart';

class StreakCalendarCard extends StatelessWidget {
  final DisciplineStats stats;
  final Function(int newGoal) onEditGoal;

  const StreakCalendarCard({
    super.key,
    required this.stats,
    required this.onEditGoal,
  });

  void _showEditGoalDialog(BuildContext context) {
    int selectedGoal = stats.dailyGoalMinutes;
    final options = [10, 15, 20, 30, 45];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Cài đặt mục tiêu mỗi ngày'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chọn thời lượng bạn cam kết luyện phát âm mỗi ngày:'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: options.map((mins) {
                    final isSelected = mins == selectedGoal;
                    return ChoiceChip(
                      label: Text('$mins phút'),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => selectedGoal = mins);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onEditGoal(selectedGoal);
                },
                child: const Text('Lưu mục tiêu'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final todayWeekday = DateTime.now().weekday - 1; // 0 = Mon, 6 = Sun

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade700,
            Colors.deepOrange.shade800,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Flame & Streak
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🔥', style: TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${stats.currentStreak} Ngày',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        stats.currentStreak >= 7
                            ? 'Phong độ xuất sắc! Tiếp tục giữ chuỗi!'
                            : 'Mỗi ngày 15 phút rèn luyện phản xạ',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded,
                        color: Colors.amberAccent, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Kỷ lục: ${stats.longestStreak}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Weekly Calendar Strip (Mon - Sun)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (idx) {
                final isDone = idx < stats.weeklyActiveDays.length &&
                    stats.weeklyActiveDays[idx];
                final isToday = idx == todayWeekday;

                return Column(
                  children: [
                    Text(
                      dayLabels[idx],
                      style: TextStyle(
                        color: isToday ? Colors.amberAccent : Colors.white.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? Colors.amberAccent
                            : isToday
                                ? Colors.white.withOpacity(0.3)
                                : Colors.white.withOpacity(0.1),
                        border: isToday
                            ? Border.all(color: Colors.amberAccent, width: 2)
                            : null,
                      ),
                      child: Icon(
                        isDone
                            ? Icons.check_rounded
                            : isToday
                                ? Icons.pending_rounded
                                : Icons.circle_outlined,
                        size: 16,
                        color: isDone ? Colors.deepOrange.shade900 : Colors.white,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 18),

          // Daily Goal Progress Bar & Edit Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hôm nay: ${stats.todayMinutes} / ${stats.dailyGoalMinutes} phút',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              InkWell(
                onTap: () => _showEditGoalDialog(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_rounded, size: 14, color: Colors.amberAccent),
                      const SizedBox(width: 4),
                      Text(
                        'Sửa mục tiêu',
                        style: TextStyle(
                          color: Colors.amberAccent.shade100,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: stats.goalProgress,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
            ),
          ),
        ],
      ),
    );
  }
}

