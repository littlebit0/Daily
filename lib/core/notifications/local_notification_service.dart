import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/events/domain/calendar_event.dart';
import '../time/korea_time.dart';
import 'notification_service.dart';

class LocalNotificationService implements NotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _briefingId = 800000;
  static const _androidChannelId = 'daily_reminders';
  static const _androidChannelName = 'Daily reminders';
  static const _androidChannelDescription =
      'Calendar reminders and daily briefing';
  static const _windowsAppUserModelId = 'Personal.Daily.Calendar';
  static const _windowsGuid = '4c124e1f-e041-4f68-aa1e-9ee8ec1a4fb7';
  final FlutterLocalNotificationsPlugin _plugin;
  var _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(KoreaTime.timeZoneName));

    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const windows = WindowsInitializationSettings(
      appName: 'Daily',
      appUserModelId: _windowsAppUserModelId,
      guid: _windowsGuid,
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      windows: windows,
    );
    await _plugin.initialize(settings: settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  @override
  Future<void> scheduleEventReminder(CalendarEvent event) async {
    await initialize();
    if (event.allDay || event.reminderMinutesBefore == null) {
      return;
    }

    final scheduled = event.startAt.subtract(
      Duration(minutes: event.reminderMinutesBefore!),
    );
    if (scheduled.isBefore(DateTime.now())) {
      return;
    }

    await _plugin.zonedSchedule(
      id: _eventNotificationId(event.id),
      title: event.title,
      body: '일정 시작 ${event.reminderMinutesBefore}분 전',
      scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: event.id,
    );
  }

  @override
  Future<void> cancelEventReminder(String eventId) async {
    await initialize();
    await _plugin.cancel(id: _eventNotificationId(eventId));
  }

  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {
    await initialize();
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: _briefingId,
      title: '오늘의 일정',
      body: '오늘 일정을 확인할 시간이에요.',
      scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'morning_briefing',
    );
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: _androidChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      windows: WindowsNotificationDetails(
        duration: WindowsNotificationDuration.short,
      ),
    );
  }

  int _eventNotificationId(String eventId) {
    final maxId = pow(2, 31).toInt();
    return eventId.codeUnits.fold<int>(
      1000,
      (value, code) => (value * 31 + code) % maxId,
    );
  }
}
