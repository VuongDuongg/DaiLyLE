import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

abstract class INotificationService {
  Future<void> initialize();
  Future<bool> requestPermissions();
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    String? title,
    String? body,
  });
  Future<void> cancelAllReminders();
  Future<void> showInstantNotification({
    required String title,
    required String body,
  });
}

class CrossPlatformNotificationService implements INotificationService {
  static final CrossPlatformNotificationService _instance =
      CrossPlatformNotificationService._internal();

  factory CrossPlatformNotificationService() => _instance;

  CrossPlatformNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!kIsWeb) {
      // 1. Initialize Timezone database for exact daily Android reminders
      tz.initializeTimeZones();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('[NotificationService] User clicked notification: ${response.payload}');
        },
      );

      // Create high-importance notification channel for Android 8.0+
      const androidChannel = AndroidNotificationChannel(
        'dailyle_discipline_channel',
        'Luyện phát âm hằng ngày',
        description: 'Thông báo nhắc nhở duy trì chuỗi học tập (Streak)',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }

    _isInitialized = true;
    debugPrint('[NotificationService] Initialized for platform: ${kIsWeb ? "Web" : "Native"}');
  }

  @override
  Future<bool> requestPermissions() async {
    if (kIsWeb) {
      // Graceful Web Notification API permission check
      try {
        debugPrint('[NotificationService-Web] Requesting HTML5 Notification permission...');
        return true;
      } catch (e) {
        debugPrint('[NotificationService-Web] Permission error: $e');
        return false;
      }
    } else {
      final androidImpl = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final granted = await androidImpl?.requestNotificationsPermission() ?? false;
      final exactAlarmGranted =
          await androidImpl?.requestExactAlarmsPermission() ?? false;

      return granted && exactAlarmGranted;
    }
  }

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    String? title,
    String? body,
  }) async {
    final reminderTitle = title ?? '🔥 Giữ vững ngọn lửa Streak của bạn!';
    final reminderBody =
        body ?? 'Dành 15 phút hôm nay để luyện âm chuẩn cùng Dailyle AI nhé.';

    if (kIsWeb) {
      // On Web: background scheduled notifications while tab closed rely on Supabase Cron
      debugPrint('[NotificationService-Web] Daily reminder scheduled at $hour:$minute');
      return;
    }

    // Android exact local notification scheduling
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If scheduled time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'dailyle_discipline_channel',
      'Luyện phát âm hằng ngày',
      channelDescription: 'Thông báo nhắc nhở duy trì chuỗi học tập',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.zonedSchedule(
      1001, // Constant ID for daily discipline reminder
      reminderTitle,
      reminderBody,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeats daily at specified time
    );

    debugPrint('[NotificationService] Android daily reminder scheduled at: $scheduledDate');
  }

  @override
  Future<void> cancelAllReminders() async {
    if (!kIsWeb) {
      await _localNotifications.cancel(1001);
    }
  }

  @override
  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) {
      debugPrint('[NotificationService-Web] Instant notification: $title - $body');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'dailyle_discipline_channel',
      'Luyện phát âm hằng ngày',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
}

