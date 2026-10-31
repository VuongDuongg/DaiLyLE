import 'package:flutter/material.dart';
import '../../../../core/notifications/notification_service.dart';

class ReminderSettingsCard extends StatefulWidget {
  final String initialTime; // e.g. "20:00:00"
  final Function(String newTime) onTimeChanged;

  const ReminderSettingsCard({
    super.key,
    required this.initialTime,
    required this.onTimeChanged,
  });

  @override
  State<ReminderSettingsCard> createState() => _ReminderSettingsCardState();
}

class _ReminderSettingsCardState extends State<ReminderSettingsCard> {
  bool _isReminderEnabled = true;
  late TimeOfDay _reminderTime;

  @override
  void initState() {
    super.initState();
    _reminderTime = _parseTime(widget.initialTime);
  }

  TimeOfDay _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 20, minute: 0);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      helpText: 'CHỌN GIỜ NHẮC NHỞ LUYỆN TẬP',
    );

    if (picked != null && picked != _reminderTime) {
      setState(() => _reminderTime = picked);
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';
      widget.onTimeChanged(formatted);

      if (_isReminderEnabled) {
        // Schedule notification
        await CrossPlatformNotificationService().scheduleDailyReminder(
          hour: picked.hour,
          minute: picked.minute,
          title: '🔥 Đến giờ luyện phát âm rồi!',
          body: 'Hãy dành 15 phút hôm nay để giữ vững chuỗi Streak bạn nhé.',
        );
      }
    }
  }

  void _toggleReminder(bool value) async {
    setState(() => _isReminderEnabled = value);
    if (value) {
      await CrossPlatformNotificationService().scheduleDailyReminder(
        hour: _reminderTime.hour,
        minute: _reminderTime.minute,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã bật nhắc nhở lúc ${_reminderTime.format(context)} hằng ngày.',
            ),
          ),
        );
      }
    } else {
      await CrossPlatformNotificationService().cancelAllReminders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tắt thông báo nhắc nhở.')),
        );
      }
    }
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_active_rounded,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nhắc nhở kỷ luật hằng ngày',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Thông báo báo thức tự động',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: _isReminderEnabled,
                onChanged: _toggleReminder,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Giờ nhắc nhở:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              InkWell(
                onTap: _isReminderEnabled ? _pickTime : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isReminderEnabled
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: _isReminderEnabled
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _reminderTime.format(context),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isReminderEnabled
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

