import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/events/domain/calendar_event.dart';
import '../settings/app_settings.dart';
import '../settings/settings_repository.dart';
import '../time/korea_time.dart';
import 'notification_service.dart';

class LocalNotificationService implements NotificationService {
  LocalNotificationService({
    required SettingsRepository settingsRepository,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _settingsRepository = settingsRepository,
       _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _briefingId = 800000;
  static const _androidChannelId = 'daily_reminders';
  static const _androidChannelName = 'Daily reminders';
  static const _androidChannelDescription =
      'Calendar reminders and daily briefing';
  static const _windowsAppUserModelId = 'Personal.Daily.Calendar';
  static const _windowsGuid = '4c124e1f-e041-4f68-aa1e-9ee8ec1a4fb7';
  static const _commonDdayOffsets = [
    -365,
    -180,
    -90,
    -60,
    -30,
    -14,
    -7,
    -3,
    -1,
    0,
  ];

  final SettingsRepository _settingsRepository;
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
    if (event.deletedAt != null || event.systemEvent || event.readOnly) {
      return;
    }

    final settings = _settingsRepository.load();
    final reminderMinutes = event.reminderMinutesBefore;
    final title = settings.hideSensitiveNotifications && event.sensitive
        ? '비공개 일정'
        : event.title;
    if (reminderMinutes != null) {
      final scheduled = _baseReminderTime(
        event,
        settings,
      ).subtract(Duration(minutes: reminderMinutes));
      await _scheduleIfFuture(
        id: _eventNotificationId(event.id),
        title: title,
        body: reminderMinutes == 0
            ? '일정이 시작됩니다.'
            : '일정 시작 ${_minutesLabel(reminderMinutes)}입니다.',
        scheduled: scheduled,
        payload: event.id,
      );
    }

    if (!event.showDday) {
      return;
    }
    for (final offset in settings.dDayReminderOffsets.toSet()) {
      final scheduled = DateTime(
        event.startAt.year,
        event.startAt.month,
        event.startAt.day,
        settings.allDayReminderHour,
        settings.allDayReminderMinute,
      ).add(Duration(days: offset));
      await _scheduleIfFuture(
        id: _eventDdayNotificationId(event.id, offset),
        title: '${_ddayLabel(offset)} $title',
        body: 'D-day 일정 알림입니다.',
        scheduled: scheduled,
        payload: '${event.id}:dday:$offset',
      );
    }
  }

  @override
  Future<void> cancelEventReminder(String eventId) async {
    await initialize();
    await _plugin.cancel(id: _eventNotificationId(eventId));
    final offsets = {
      ..._commonDdayOffsets,
      ..._settingsRepository.load().dDayReminderOffsets,
    };
    for (final offset in offsets) {
      await _plugin.cancel(id: _eventDdayNotificationId(eventId, offset));
    }
  }

  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {
    await initialize();
    await cancelMorningBriefing();
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: _briefingId,
      title: '오늘의 일정',
      body: '오늘 일정을 확인할 시간입니다.',
      scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'morning_briefing',
    );
  }

  @override
  Future<void> cancelMorningBriefing() async {
    await initialize();
    await _plugin.cancel(id: _briefingId);
  }

  Future<void> _scheduleIfFuture({
    required int id,
    required String title,
    required String body,
    required DateTime scheduled,
    required String payload,
  }) async {
    if (!scheduled.isAfter(DateTime.now())) {
      return;
    }

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  DateTime _baseReminderTime(CalendarEvent event, AppSettings settings) {
    if (!event.allDay) {
      return event.startAt;
    }
    return DateTime(
      event.startAt.year,
      event.startAt.month,
      event.startAt.day,
      settings.allDayReminderHour,
      settings.allDayReminderMinute,
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
    return _notificationId(eventId, 1000);
  }

  int _eventDdayNotificationId(String eventId, int offset) {
    return _notificationId('$eventId:dday:$offset', 500000);
  }

  int _notificationId(String value, int seed) {
    final maxId = pow(2, 31).toInt();
    return value.codeUnits.fold<int>(
      seed,
      (hash, code) => (hash * 31 + code) % maxId,
    );
  }

  String _minutesLabel(int minutes) {
    if (minutes == 0) {
      return '정시';
    }
    if (minutes < 60) {
      return '$minutes분 전';
    }
    if (minutes % 1440 == 0) {
      return '${minutes ~/ 1440}일 전';
    }
    if (minutes % 60 == 0) {
      return '${minutes ~/ 60}시간 전';
    }
    return '$minutes분 전';
  }

  String _ddayLabel(int offset) {
    if (offset == 0) {
      return 'D-day';
    }
    return offset < 0 ? 'D$offset' : 'D+$offset';
  }
}
