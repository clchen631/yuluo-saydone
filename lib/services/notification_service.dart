import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static const _dailyNotificationId = 0;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    // Navigate to home tab handled by app.dart
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    int incompleteCount = 0,
    List<String> taskTitles = const [],
  }) async {
    if (!_initialized) await init();

    await _plugin.cancel(_dailyNotificationId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'daily_reminder',
      '每日未完成任务提醒',
      channelDescription: '每天定时提醒未完成的任务',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = incompleteCount > 0
        ? '今日还有 $incompleteCount 个任务未完成'
        : '今日任务检查';
    String body;
    if (taskTitles.isNotEmpty) {
      final titlesText = taskTitles.take(2).join('、');
      body = incompleteCount > 2 ? '$titlesText 等' : titlesText;
    } else {
      body = incompleteCount > 0 ? '打开应用查看未完成任务' : '暂无未完成任务';
    }

    await _plugin.zonedSchedule(
      _dailyNotificationId,
      title,
      body,
      scheduledTime,
      details,
      payload: 'home',
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() async {
    if (!_initialized) await init();
    await _plugin.cancel(_dailyNotificationId);
  }

  Future<void> rescheduleFromSettings({
    required bool enabled,
    required int hour,
    required int minute,
    int incompleteCount = 0,
    List<String> taskTitles = const [],
  }) async {
    if (!enabled) {
      await cancelDailyReminder();
      return;
    }
    await scheduleDailyReminder(
      hour: hour,
      minute: minute,
      incompleteCount: incompleteCount,
      taskTitles: taskTitles,
    );
  }
}
