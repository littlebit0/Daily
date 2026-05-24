import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_category.dart';
import '../../features/events/domain/event_repository.dart';
import '../../features/events/domain/recurrence_rule.dart';
import '../notifications/notification_service.dart';
import '../settings/app_settings.dart';
import '../settings/settings_repository.dart';
import 'google_drive_auth_service.dart';
import 'sync_service.dart';

class GoogleDriveSyncService implements SyncService {
  GoogleDriveSyncService({
    required GoogleDriveAuthService authService,
    required EventRepository eventRepository,
    required NotificationService notificationService,
    required SettingsRepository settingsRepository,
    http.Client? httpClient,
  }) : _authService = authService,
       _eventRepository = eventRepository,
       _notificationService = notificationService,
       _settingsRepository = settingsRepository,
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null;

  static const _syncFileName = 'daily-sync-v1.json';
  static const _driveHost = 'www.googleapis.com';
  static const _autoSyncInterval = Duration(seconds: 20);
  static const _changeSyncDelay = Duration(milliseconds: 300);

  final GoogleDriveAuthService _authService;
  final EventRepository _eventRepository;
  final NotificationService _notificationService;
  final SettingsRepository _settingsRepository;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  Future<void>? _syncInFlight;
  StreamSubscription<GoogleDriveAccount?>? _accountSubscription;
  Timer? _autoSyncTimer;
  Timer? _changeSyncTimer;
  var _started = false;
  var _syncAgainRequested = false;
  var _nextPromptIfNecessary = false;

  final statusNotifier = ValueNotifier<GoogleDriveSyncStatus>(
    const GoogleDriveSyncStatus(),
  );

  @override
  Future<void> start() async {
    if (_started) {
      return syncNow();
    }
    _started = true;

    await _authService.initialize();
    _accountSubscription = _authService.accountChanges.listen((account) {
      if (account != null) {
        _requestAutomaticSync();
      }
    });
    _autoSyncTimer = Timer.periodic(
      _autoSyncInterval,
      (_) => _requestAutomaticSync(),
    );
    await syncNow().catchError((_) {});
  }

  @override
  Future<void> queueEventUpsert(CalendarEvent event) {
    _queueChangeSync();
    return Future.value();
  }

  @override
  Future<void> queueEventDelete(String eventId) {
    _queueChangeSync();
    return Future.value();
  }

  Future<void> syncNow({bool promptIfNecessary = false}) {
    _nextPromptIfNecessary = _nextPromptIfNecessary || promptIfNecessary;
    _syncAgainRequested = true;

    final inFlight = _syncInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    return _syncInFlight = _drainSyncQueue().whenComplete(() {
      _syncInFlight = null;
    });
  }

  Future<void> deleteCloudBackup({bool promptIfNecessary = false}) async {
    _changeSyncTimer?.cancel();
    _syncAgainRequested = false;
    final inFlight = _syncInFlight;
    if (inFlight != null) {
      await inFlight;
    }

    final headers = await _authService.authorizationHeaders(
      promptIfNecessary: promptIfNecessary,
    );
    if (headers == null) {
      return;
    }

    final remoteFile = await _findSyncFile(headers);
    if (remoteFile == null) {
      return;
    }

    final response = await _httpClient.delete(
      Uri.https(_driveHost, '/drive/v3/files/${remoteFile.id}'),
      headers: headers,
    );
    _throwIfFailed(response);
  }

  void dispose() {
    _changeSyncTimer?.cancel();
    _autoSyncTimer?.cancel();
    unawaited(_accountSubscription?.cancel());
    statusNotifier.dispose();
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  Future<void> _drainSyncQueue() async {
    while (_syncAgainRequested) {
      final promptIfNecessary = _nextPromptIfNecessary;
      _syncAgainRequested = false;
      _nextPromptIfNecessary = false;
      await _sync(promptIfNecessary: promptIfNecessary);
    }
  }

  void _queueChangeSync() {
    _changeSyncTimer?.cancel();
    _changeSyncTimer = Timer(_changeSyncDelay, _requestAutomaticSync);
  }

  void _requestAutomaticSync() {
    unawaited(syncNow().catchError((_) {}));
  }

  Future<void> _sync({required bool promptIfNecessary}) async {
    statusNotifier.value = statusNotifier.value.copyWith(
      syncing: true,
      message: '동기화 중',
      clearError: true,
    );
    try {
      final headers = await _authService.authorizationHeaders(
        promptIfNecessary: promptIfNecessary,
      );
      if (headers == null) {
        statusNotifier.value = statusNotifier.value.copyWith(
          syncing: false,
          message: 'Google 로그인이 필요합니다.',
        );
        return;
      }

      final localEvents = await _eventRepository.allEventsForSync();
      final localSettings = _settingsRepository.load();
      final remoteFile = await _findSyncFile(headers);
      final remoteSnapshot = remoteFile == null
          ? const _SyncSnapshot(events: <CalendarEvent>[])
          : await _downloadSnapshot(headers, remoteFile.id);
      final remoteSettings = remoteSnapshot.settings;
      if (remoteSettings != null && _shouldAdoptRemoteSettings(localSettings)) {
        await _settingsRepository.save(
          remoteSettings.copyWith(
            onboardingCompleted: localSettings.onboardingCompleted,
            appLockEnabled: localSettings.appLockEnabled,
          ),
        );
      }
      final merged = _merge(localEvents, remoteSnapshot.events);

      for (final event in merged) {
        final synced = event.copyWith(syncStatus: 'synced');
        await _eventRepository.save(synced);
        await _notificationService.cancelEventReminder(synced.id);
        if (synced.deletedAt == null) {
          await _notificationService.scheduleEventReminder(synced);
        }
      }

      final jsonBody = _encodeSnapshot(
        merged.map((event) => event.copyWith(syncStatus: 'synced')).toList(),
        _settingsRepository.load(),
      );
      if (remoteFile == null) {
        await _createSyncFile(headers, jsonBody);
      } else {
        await _updateSyncFile(headers, remoteFile.id, jsonBody);
      }
      statusNotifier.value = statusNotifier.value.copyWith(
        syncing: false,
        lastSyncedAt: DateTime.now(),
        message: '동기화 완료',
        clearError: true,
      );
    } on Object catch (error) {
      statusNotifier.value = statusNotifier.value.copyWith(
        syncing: false,
        message: '동기화 실패',
        error: '$error',
      );
      rethrow;
    }
  }

  List<CalendarEvent> _merge(
    List<CalendarEvent> localEvents,
    List<CalendarEvent> remoteEvents,
  ) {
    final merged = <String, CalendarEvent>{};

    for (final event in remoteEvents) {
      merged[event.id] = event.copyWith(syncStatus: 'synced');
    }

    for (final event in localEvents) {
      final remote = merged[event.id];
      if (remote == null || event.syncStatus != 'synced') {
        merged[event.id] = event;
        continue;
      }
      if (_effectiveUpdatedAt(event).isAfter(_effectiveUpdatedAt(remote))) {
        merged[event.id] = event;
      }
    }

    return merged.values.toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
  }

  DateTime _effectiveUpdatedAt(CalendarEvent event) {
    final deletedAt = event.deletedAt;
    if (deletedAt != null && deletedAt.isAfter(event.updatedAt)) {
      return deletedAt;
    }
    return event.updatedAt;
  }

  Future<_DriveFile?> _findSyncFile(Map<String, String> authHeaders) async {
    final response = await _httpClient.get(
      Uri.https(_driveHost, '/drive/v3/files', {
        'spaces': 'appDataFolder',
        'q': "name = '$_syncFileName' and trashed = false",
        'fields': 'files(id,name,modifiedTime)',
        'pageSize': '1',
      }),
      headers: authHeaders,
    );
    _throwIfFailed(response);

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final files = decoded['files'];
    if (files is! List || files.isEmpty) {
      return null;
    }
    final first = files.first as Map<String, Object?>;
    return _DriveFile(id: first['id'] as String);
  }

  Future<_SyncSnapshot> _downloadSnapshot(
    Map<String, String> authHeaders,
    String fileId,
  ) async {
    final response = await _httpClient.get(
      Uri.https(_driveHost, '/drive/v3/files/$fileId', {'alt': 'media'}),
      headers: authHeaders,
    );
    _throwIfFailed(response);

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final events = decoded['events'];
    final parsedEvents = events is List
        ? events
              .whereType<Map>()
              .map((item) => Map<String, Object?>.from(item))
              .map(_eventFromJson)
              .whereType<CalendarEvent>()
              .toList()
        : const <CalendarEvent>[];
    final settings = decoded['settings'];
    return _SyncSnapshot(
      events: parsedEvents,
      settings: settings is Map
          ? _settingsFromJson(Map<String, Object?>.from(settings))
          : null,
    );
  }

  Future<void> _createSyncFile(
    Map<String, String> authHeaders,
    String jsonBody,
  ) async {
    final boundary = 'daily-sync-${DateTime.now().microsecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': _syncFileName,
      'parents': ['appDataFolder'],
    });
    final body = utf8.encode(
      '--$boundary\r\n'
      'Content-Type: application/json; charset=UTF-8\r\n\r\n'
      '$metadata\r\n'
      '--$boundary\r\n'
      'Content-Type: application/json; charset=UTF-8\r\n\r\n'
      '$jsonBody\r\n'
      '--$boundary--\r\n',
    );

    final response = await _httpClient.post(
      Uri.https(_driveHost, '/upload/drive/v3/files', {
        'uploadType': 'multipart',
        'fields': 'id',
      }),
      headers: {
        ...authHeaders,
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );
    _throwIfFailed(response);
  }

  Future<void> _updateSyncFile(
    Map<String, String> authHeaders,
    String fileId,
    String jsonBody,
  ) async {
    final response = await _httpClient.patch(
      Uri.https(_driveHost, '/upload/drive/v3/files/$fileId', {
        'uploadType': 'media',
        'fields': 'id',
      }),
      headers: {
        ...authHeaders,
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: utf8.encode(jsonBody),
    );
    _throwIfFailed(response);
  }

  void _throwIfFailed(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw GoogleDriveSyncException(
      'Google 계정 동기화 실패: HTTP ${response.statusCode} ${response.body}',
    );
  }

  String _encodeSnapshot(List<CalendarEvent> events, AppSettings settings) {
    return jsonEncode({
      'schemaVersion': 1,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'events': events.map(_eventToJson).toList(),
      'settings': _settingsToJson(settings),
    });
  }

  Map<String, Object?> _eventToJson(CalendarEvent event) {
    return {
      'id': event.id,
      'title': event.title,
      'memo': event.memo,
      'location': event.location,
      'url': event.url,
      'weather': event.weather,
      'startAt': event.startAt.toUtc().toIso8601String(),
      'endAt': event.endAt.toUtc().toIso8601String(),
      'allDay': event.allDay,
      'category': event.category.name,
      'categoryLabel': event.category.label,
      'categoryLocked': event.category.locked,
      'colorValue': event.colorValue,
      'reminderMinutesBefore': event.reminderMinutesBefore,
      'recurrenceFrequency': event.recurrence.frequency.name,
      'recurrenceInterval': event.recurrence.interval,
      'recurrenceUntil': event.recurrence.until?.toUtc().toIso8601String(),
      'recurrenceCount': event.recurrence.count,
      'recurrenceExcludedDates': event.recurrence.excludedDates
          .map((date) => DateTime(date.year, date.month, date.day))
          .map((date) => date.toUtc().toIso8601String())
          .toList(),
      'createdAt': event.createdAt.toUtc().toIso8601String(),
      'updatedAt': event.updatedAt.toUtc().toIso8601String(),
      'deletedAt': event.deletedAt?.toUtc().toIso8601String(),
      'deviceId': event.deviceId,
      'showDday': event.showDday,
      'sensitive': event.sensitive,
    };
  }

  CalendarEvent? _eventFromJson(Map<String, Object?> json) {
    final id = json['id'] as String?;
    final startAt = _readDate(json['startAt']);
    final endAt = _readDate(json['endAt']);
    final createdAt = _readDate(json['createdAt']);
    final updatedAt = _readDate(json['updatedAt']);
    if (id == null ||
        startAt == null ||
        endAt == null ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    final colorValue = json['colorValue'] as int?;
    final category = _categoryFromJson(json, colorValue);
    return CalendarEvent(
      id: id,
      title: json['title'] as String? ?? 'New event',
      memo: json['memo'] as String?,
      location: json['location'] as String?,
      url: json['url'] as String?,
      weather: json['weather'] as String?,
      startAt: startAt,
      endAt: endAt,
      allDay: json['allDay'] as bool? ?? false,
      category: category,
      colorValue: colorValue ?? category.colorValue,
      reminderMinutesBefore: json['reminderMinutesBefore'] as int?,
      recurrence: RecurrenceRule(
        frequency: RecurrenceFrequency.fromName(
          json['recurrenceFrequency'] as String?,
        ),
        interval: json['recurrenceInterval'] as int? ?? 1,
        until: _readDate(json['recurrenceUntil']),
        count: json['recurrenceCount'] as int?,
        excludedDates: _dateListValue(json['recurrenceExcludedDates']),
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: _readDate(json['deletedAt']),
      deviceId: json['deviceId'] as String? ?? '',
      syncStatus: 'synced',
      showDday: json['showDday'] as bool? ?? false,
      sensitive: json['sensitive'] as bool? ?? false,
    );
  }

  DateTime? _readDate(Object? value) {
    if (value is! String) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal();
  }

  List<DateTime> _dateListValue(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<String>()
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .map((date) => date.toLocal())
        .map((date) => DateTime(date.year, date.month, date.day))
        .toList();
  }

  EventCategory _categoryFromJson(Map<String, Object?> json, int? colorValue) {
    final rawCategory = json['category'] as String?;
    final label = json['categoryLabel'] as String?;
    if (label != null && label.isNotEmpty) {
      return EventCategory.fromJson({
        'id': rawCategory ?? '',
        'label': label,
        'colorValue': colorValue,
        'locked': json['categoryLocked'] as bool? ?? false,
      });
    }
    return EventCategory.fromStored(rawCategory, colorValue: colorValue);
  }

  Map<String, Object?> _settingsToJson(AppSettings settings) {
    return {
      'defaultReminderMinutes': settings.defaultReminderMinutes,
      'allDayReminderHour': settings.allDayReminderHour,
      'allDayReminderMinute': settings.allDayReminderMinute,
      'morningBriefingHour': settings.morningBriefingHour,
      'morningBriefingMinute': settings.morningBriefingMinute,
      'morningBriefingEnabled': settings.morningBriefingEnabled,
      'weekStartsOnMonday': settings.weekStartsOnMonday,
      'showLunarDates': settings.showLunarDates,
      'onboardingCompleted': settings.onboardingCompleted,
      'aiEnabled': settings.aiEnabled,
      'aiOnlyForComplexInput': settings.aiOnlyForComplexInput,
      'blockSensitiveAi': settings.blockSensitiveAi,
      'categories': settings.categories
          .map((category) => category.toJson())
          .toList(),
      'dDayReminderOffsets': settings.dDayReminderOffsets,
      'calendarDensity': settings.calendarDensity.name,
      'defaultCalendarView': settings.defaultCalendarView.name,
      'hiddenCategoryIds': settings.hiddenCategoryIds,
      'calendarShowHolidays': settings.calendarShowHolidays,
      'calendarDdayOnly': settings.calendarDdayOnly,
      'hideSensitiveEvents': settings.hideSensitiveEvents,
      'hideSensitiveNotifications': settings.hideSensitiveNotifications,
    };
  }

  AppSettings _settingsFromJson(Map<String, Object?> json) {
    return AppSettings(
      defaultReminderMinutes: _intValue(json['defaultReminderMinutes'], 60),
      allDayReminderHour: _intValue(json['allDayReminderHour'], 9),
      allDayReminderMinute: _intValue(json['allDayReminderMinute'], 0),
      morningBriefingHour: _intValue(json['morningBriefingHour'], 8),
      morningBriefingMinute: _intValue(json['morningBriefingMinute'], 0),
      morningBriefingEnabled: json['morningBriefingEnabled'] as bool? ?? true,
      weekStartsOnMonday: json['weekStartsOnMonday'] as bool? ?? false,
      showLunarDates: json['showLunarDates'] as bool? ?? true,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      aiEnabled: json['aiEnabled'] as bool? ?? false,
      aiOnlyForComplexInput: json['aiOnlyForComplexInput'] as bool? ?? true,
      blockSensitiveAi: json['blockSensitiveAi'] as bool? ?? true,
      categories: _categoriesFromJson(json['categories']),
      dDayReminderOffsets: _intListValue(json['dDayReminderOffsets'], const [
        -7,
        -3,
        -1,
        0,
      ]),
      calendarDensity: CalendarDensity.fromName(
        json['calendarDensity'] as String?,
      ),
      defaultCalendarView: CalendarViewMode.fromName(
        json['defaultCalendarView'] as String?,
      ),
      hiddenCategoryIds: _stringListValue(json['hiddenCategoryIds']),
      calendarShowHolidays: json['calendarShowHolidays'] as bool? ?? true,
      calendarDdayOnly: json['calendarDdayOnly'] as bool? ?? false,
      hideSensitiveEvents: json['hideSensitiveEvents'] as bool? ?? false,
      hideSensitiveNotifications:
          json['hideSensitiveNotifications'] as bool? ?? false,
    );
  }

  List<EventCategory> _categoriesFromJson(Object? value) {
    if (value is! List) {
      return const [EventCategory.basic, EventCategory.holiday];
    }
    final categories = value
        .whereType<Map>()
        .map((item) => EventCategory.fromJson(Map<String, Object?>.from(item)))
        .where((category) => category.id.isNotEmpty)
        .toList();
    if (!categories.any(
      (category) => category.id == EventCategory.holiday.id,
    )) {
      categories.add(EventCategory.holiday);
    }
    return categories;
  }

  List<int> _intListValue(Object? value, List<int> fallback) {
    if (value is! List) {
      return fallback;
    }
    final items = value.whereType<int>().toList();
    return items.isEmpty ? fallback : (items..sort());
  }

  List<String> _stringListValue(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value.whereType<String>().toList();
  }

  int _intValue(Object? value, int fallback) {
    return value is int ? value : fallback;
  }

  bool _shouldAdoptRemoteSettings(AppSettings local) {
    final defaultCategoryIds = local.categories
        .map((category) => category.id)
        .toSet();
    return local.defaultReminderMinutes == 60 &&
        local.allDayReminderHour == 9 &&
        local.allDayReminderMinute == 0 &&
        local.morningBriefingHour == 8 &&
        local.morningBriefingMinute == 0 &&
        local.morningBriefingEnabled &&
        !local.weekStartsOnMonday &&
        local.showLunarDates &&
        defaultCategoryIds.length == 2 &&
        defaultCategoryIds.contains(EventCategory.basic.id) &&
        defaultCategoryIds.contains(EventCategory.holiday.id) &&
        _sameIntList(local.dDayReminderOffsets, const [-7, -3, -1, 0]) &&
        local.calendarDensity == CalendarDensity.standard &&
        local.defaultCalendarView == CalendarViewMode.week &&
        local.hiddenCategoryIds.isEmpty &&
        local.calendarShowHolidays &&
        !local.calendarDdayOnly &&
        !local.hideSensitiveEvents &&
        !local.hideSensitiveNotifications;
  }

  bool _sameIntList(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    final sortedA = [...a]..sort();
    final sortedB = [...b]..sort();
    for (var index = 0; index < sortedA.length; index++) {
      if (sortedA[index] != sortedB[index]) {
        return false;
      }
    }
    return true;
  }
}

class GoogleDriveSyncException implements Exception {
  const GoogleDriveSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GoogleDriveSyncStatus {
  const GoogleDriveSyncStatus({
    this.syncing = false,
    this.lastSyncedAt,
    this.message = '',
    this.error,
  });

  final bool syncing;
  final DateTime? lastSyncedAt;
  final String message;
  final String? error;

  GoogleDriveSyncStatus copyWith({
    bool? syncing,
    DateTime? lastSyncedAt,
    String? message,
    String? error,
    bool clearError = false,
  }) {
    return GoogleDriveSyncStatus(
      syncing: syncing ?? this.syncing,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      message: message ?? this.message,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class _DriveFile {
  const _DriveFile({required this.id});

  final String id;
}

class _SyncSnapshot {
  const _SyncSnapshot({required this.events, this.settings});

  final List<CalendarEvent> events;
  final AppSettings? settings;
}
