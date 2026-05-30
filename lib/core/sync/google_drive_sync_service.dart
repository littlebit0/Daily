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

  static const _legacySyncFileName = 'daily-sync-v1.json';
  static const _settingsFileName = 'daily-sync-v2-settings.json';
  static const _eventFilePrefix = 'daily-sync-v2-event-';
  static const _eventFileSuffix = '.json';
  static const _v2FilePrefix = 'daily-sync-v2-';
  static const _driveHost = 'www.googleapis.com';
  static const _changeSyncDelay = Duration(seconds: 1);

  final GoogleDriveAuthService _authService;
  final EventRepository _eventRepository;
  final NotificationService _notificationService;
  final SettingsRepository _settingsRepository;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  Future<void>? _syncInFlight;
  StreamSubscription<GoogleDriveAccount?>? _accountSubscription;
  Timer? _changeSyncTimer;
  final _queuedEventIds = <String>{};
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
    await syncNow().catchError((_) {});
  }

  @override
  Future<void> queueEventUpsert(CalendarEvent event) {
    _queuedEventIds.add(event.id);
    _queueChangeSync();
    return Future.value();
  }

  @override
  Future<void> queueEventDelete(String eventId) {
    _queuedEventIds.add(eventId);
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

    final files = <_DriveFile>[
      ...await _listFiles(
        headers,
        "name contains '$_v2FilePrefix' and trashed = false",
      ),
      ...await _listFiles(
        headers,
        "name = '$_legacySyncFileName' and trashed = false",
      ),
    ];

    for (final file in files) {
      final response = await _httpClient.delete(
        Uri.https(_driveHost, '/drive/v3/files/${file.id}'),
        headers: headers,
      );
      _throwIfFailed(response);
    }
  }

  void dispose() {
    _changeSyncTimer?.cancel();
    unawaited(_accountSubscription?.cancel());
    statusNotifier.dispose();
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  Future<void> _drainSyncQueue() async {
    while (_syncAgainRequested) {
      final promptIfNecessary = _nextPromptIfNecessary;
      final queuedEventIds = _queuedEventIds.isEmpty
          ? null
          : Set<String>.from(_queuedEventIds);
      _queuedEventIds.clear();
      _syncAgainRequested = false;
      _nextPromptIfNecessary = false;
      await _sync(
        promptIfNecessary: promptIfNecessary,
        eventIds: queuedEventIds,
      );
    }
  }

  void _queueChangeSync() {
    _changeSyncTimer?.cancel();
    _changeSyncTimer = Timer(_changeSyncDelay, _requestAutomaticSync);
  }

  void _requestAutomaticSync() {
    unawaited(syncNow().catchError((_) {}));
  }

  Future<void> _sync({
    required bool promptIfNecessary,
    Set<String>? eventIds,
  }) async {
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

      if (eventIds == null || eventIds.isEmpty) {
        final localSettings = _settingsRepository.load();
        await _syncSettings(headers, localSettings);
        await _syncAllEvents(headers);
      } else {
        await _syncQueuedEvents(headers, eventIds);
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

  Future<void> _syncSettings(
    Map<String, String> authHeaders,
    AppSettings localSettings,
  ) async {
    final settingsFile = await _findFileByName(authHeaders, _settingsFileName);
    if (settingsFile != null) {
      final remoteSettings = await _downloadSettingsFile(
        authHeaders,
        settingsFile.id,
      );
      if (remoteSettings != null && _shouldAdoptRemoteSettings(localSettings)) {
        await _settingsRepository.save(
          remoteSettings.copyWith(
            onboardingCompleted: localSettings.onboardingCompleted,
            appLockEnabled: localSettings.appLockEnabled,
          ),
        );
      }
    }

    await _uploadJsonFile(
      authHeaders,
      fileName: _settingsFileName,
      fileId: settingsFile?.id,
      jsonBody: _encodeSettingsFile(_settingsRepository.load()),
    );
  }

  Future<void> _syncAllEvents(Map<String, String> authHeaders) async {
    final localEvents = await _eventRepository.allEventsForSync();
    final localById = {for (final event in localEvents) event.id: event};
    final remoteFiles = await _listEventFiles(authHeaders);
    final remoteById = <String, CalendarEvent>{};
    final remoteFileById = <String, _DriveFile>{};

    for (final entry in remoteFiles.entries) {
      final remoteEvent = await _downloadEventFile(authHeaders, entry.value.id);
      if (remoteEvent == null) {
        continue;
      }
      remoteFileById[entry.key] = entry.value;
      final existing = remoteById[entry.key];
      if (existing == null ||
          _effectiveUpdatedAt(
            remoteEvent,
          ).isAfter(_effectiveUpdatedAt(existing))) {
        remoteById[entry.key] = remoteEvent;
      }
    }

    final merged = _merge(localEvents, remoteById.values.toList());
    for (final event in merged) {
      final local = localById[event.id];
      final remote = remoteById[event.id];
      final shouldUpload =
          local != null &&
          (remote == null ||
              local.syncStatus != 'synced' ||
              _effectiveUpdatedAt(local).isAfter(_effectiveUpdatedAt(remote)));

      if (shouldUpload) {
        await _uploadEventFile(authHeaders, event, remoteFileById[event.id]);
      }
      await _saveSyncedEvent(event);
    }
  }

  Future<void> _syncQueuedEvents(
    Map<String, String> authHeaders,
    Set<String> eventIds,
  ) async {
    for (final eventId in eventIds) {
      final local = await _eventRepository.findById(eventId);
      final remoteFile = await _findFileByName(
        authHeaders,
        _eventFileName(eventId),
      );
      final remote = remoteFile == null
          ? null
          : await _downloadEventFile(authHeaders, remoteFile.id);

      if (local == null) {
        if (remote != null) {
          await _saveSyncedEvent(remote);
        }
        continue;
      }

      final shouldUpload =
          remote == null ||
          local.syncStatus != 'synced' ||
          _effectiveUpdatedAt(local).isAfter(_effectiveUpdatedAt(remote));
      if (shouldUpload) {
        await _uploadEventFile(authHeaders, local, remoteFile);
        await _saveSyncedEvent(local);
      } else {
        await _saveSyncedEvent(remote);
      }
    }
  }

  Future<void> _saveSyncedEvent(CalendarEvent event) async {
    final synced = event.copyWith(syncStatus: 'synced');
    await _eventRepository.save(synced);
    await _notificationService.cancelEventReminder(synced.id);
    if (synced.deletedAt == null) {
      await _notificationService.scheduleEventReminder(synced);
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

  Future<Map<String, _DriveFile>> _listEventFiles(
    Map<String, String> authHeaders,
  ) async {
    final files = await _listFiles(
      authHeaders,
      "name contains '$_eventFilePrefix' and trashed = false",
    );
    final result = <String, _DriveFile>{};
    for (final file in files) {
      final eventId = _eventIdFromFileName(file.name);
      if (eventId != null) {
        result[eventId] = file;
      }
    }
    return result;
  }

  Future<_DriveFile?> _findFileByName(
    Map<String, String> authHeaders,
    String name,
  ) async {
    final files = await _listFiles(
      authHeaders,
      "name = '$name' and trashed = false",
      pageSize: 1,
    );
    return files.isEmpty ? null : files.first;
  }

  Future<List<_DriveFile>> _listFiles(
    Map<String, String> authHeaders,
    String query, {
    int pageSize = 1000,
  }) async {
    final files = <_DriveFile>[];
    String? pageToken;
    do {
      final queryParameters = {
        'spaces': 'appDataFolder',
        'q': query,
        'fields': 'nextPageToken,files(id,name,modifiedTime)',
        'pageSize': '$pageSize',
      };
      final token = pageToken;
      if (token != null) {
        queryParameters['pageToken'] = token;
      }
      final response = await _httpClient.get(
        Uri.https(_driveHost, '/drive/v3/files', queryParameters),
        headers: authHeaders,
      );
      _throwIfFailed(response);

      final decoded = jsonDecode(response.body) as Map<String, Object?>;
      final rawFiles = decoded['files'];
      if (rawFiles is List) {
        files.addAll(
          rawFiles
              .whereType<Map>()
              .map((item) => Map<String, Object?>.from(item))
              .map(_DriveFile.tryFromJson)
              .whereType<_DriveFile>(),
        );
      }
      pageToken = decoded['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);
    return files;
  }

  Future<CalendarEvent?> _downloadEventFile(
    Map<String, String> authHeaders,
    String fileId,
  ) async {
    final response = await _httpClient.get(
      Uri.https(_driveHost, '/drive/v3/files/$fileId', {'alt': 'media'}),
      headers: authHeaders,
    );
    _throwIfFailed(response);

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final event = decoded['event'];
    return _eventFromJson(
      event is Map ? Map<String, Object?>.from(event) : decoded,
    );
  }

  Future<AppSettings?> _downloadSettingsFile(
    Map<String, String> authHeaders,
    String fileId,
  ) async {
    final response = await _httpClient.get(
      Uri.https(_driveHost, '/drive/v3/files/$fileId', {'alt': 'media'}),
      headers: authHeaders,
    );
    _throwIfFailed(response);

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final settings = decoded['settings'];
    if (settings is! Map) {
      return null;
    }
    return _settingsFromJson(Map<String, Object?>.from(settings));
  }

  Future<void> _uploadEventFile(
    Map<String, String> authHeaders,
    CalendarEvent event,
    _DriveFile? remoteFile,
  ) async {
    await _uploadJsonFile(
      authHeaders,
      fileName: _eventFileName(event.id),
      fileId: remoteFile?.id,
      jsonBody: _encodeEventFile(event),
    );
  }

  Future<void> _uploadJsonFile(
    Map<String, String> authHeaders, {
    required String fileName,
    required String jsonBody,
    String? fileId,
  }) async {
    if (fileId != null) {
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
      return;
    }

    final boundary = 'daily-sync-v2-${DateTime.now().microsecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': fileName,
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

  void _throwIfFailed(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw GoogleDriveSyncException(
      'Google 계정 동기화 실패: HTTP ${response.statusCode} ${response.body}',
    );
  }

  String _encodeEventFile(CalendarEvent event) {
    return jsonEncode({
      'schemaVersion': 2,
      'type': 'event',
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'event': _eventToJson(event),
    });
  }

  String _encodeSettingsFile(AppSettings settings) {
    return jsonEncode({
      'schemaVersion': 2,
      'type': 'settings',
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'settings': _settingsToJson(settings),
    });
  }

  String _eventFileName(String eventId) {
    return '$_eventFilePrefix$eventId$_eventFileSuffix';
  }

  String? _eventIdFromFileName(String fileName) {
    if (!fileName.startsWith(_eventFilePrefix) ||
        !fileName.endsWith(_eventFileSuffix)) {
      return null;
    }
    return fileName.substring(
      _eventFilePrefix.length,
      fileName.length - _eventFileSuffix.length,
    );
  }

  Map<String, Object?> _eventToJson(CalendarEvent event) {
    final normalized = event.normalizeAllDayBounds();
    return {
      'id': normalized.id,
      'title': normalized.title,
      'memo': normalized.memo,
      'location': normalized.location,
      'url': normalized.url,
      'weather': normalized.weather,
      'startAt': _dateTimeToJson(normalized.startAt, normalized.allDay),
      'endAt': _dateTimeToJson(normalized.endAt, normalized.allDay),
      if (normalized.allDay) ...{
        'startDate': _dateOnlyToJson(normalized.startAt),
        'endDate': _dateOnlyToJson(normalized.endAt),
      },
      'allDay': normalized.allDay,
      'category': normalized.category.name,
      'categoryLabel': normalized.category.label,
      'categoryLocked': normalized.category.locked,
      'colorValue': normalized.colorValue,
      'reminderMinutesBefore': normalized.reminderMinutesBefore,
      'recurrenceFrequency': normalized.recurrence.frequency.name,
      'recurrenceInterval': normalized.recurrence.interval,
      'recurrenceUntil': normalized.recurrence.until?.toUtc().toIso8601String(),
      'recurrenceCount': normalized.recurrence.count,
      'recurrenceExcludedDates': normalized.recurrence.excludedDates
          .map((date) => DateTime(date.year, date.month, date.day))
          .map((date) => date.toUtc().toIso8601String())
          .toList(),
      'createdAt': normalized.createdAt.toUtc().toIso8601String(),
      'updatedAt': normalized.updatedAt.toUtc().toIso8601String(),
      'deletedAt': normalized.deletedAt?.toUtc().toIso8601String(),
      'deviceId': normalized.deviceId,
      'showDday': normalized.showDday,
      'sensitive': normalized.sensitive,
    };
  }

  CalendarEvent? _eventFromJson(Map<String, Object?> json) {
    final id = json['id'] as String?;
    final allDay = json['allDay'] as bool? ?? false;
    final startAt = allDay
        ? _readAllDayDate(json['startDate'] ?? json['startAt'])
        : _readDate(json['startAt']);
    final endAt = allDay
        ? _readAllDayDate(json['endDate'] ?? json['endAt'])
        : _readDate(json['endAt']);
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
      allDay: allDay,
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
    ).normalizeAllDayBounds();
  }

  String _dateTimeToJson(DateTime value, bool allDay) {
    if (allDay) {
      return DateTime(value.year, value.month, value.day).toIso8601String();
    }
    return value.toUtc().toIso8601String();
  }

  String _dateOnlyToJson(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  DateTime? _readDate(Object? value) {
    if (value is! String) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal();
  }

  DateTime? _readAllDayDate(Object? value) {
    if (value is! String) {
      return null;
    }
    final datePrefix = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
    if (datePrefix != null) {
      final year = int.parse(datePrefix.group(1)!);
      final month = int.parse(datePrefix.group(2)!);
      final day = int.parse(datePrefix.group(3)!);
      final date = DateTime(year, month, day);
      if (date.year == year && date.month == month && date.day == day) {
        return date;
      }
    }
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) {
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
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
  const _DriveFile({required this.id, required this.name});

  static _DriveFile? tryFromJson(Map<String, Object?> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    if (id == null || name == null) {
      return null;
    }
    return _DriveFile(id: id, name: name);
  }

  final String id;
  final String name;
}
