import 'dart:async';
import 'dart:convert';

import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/sync/google_drive_sync_service.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restore sync downloads v2 event files without uploading', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final requests = <http.Request>[];
    final httpClient = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
        final query = request.url.queryParameters['q'] ?? '';
        if (query.contains('daily-sync-v2-settings.json')) {
          return _driveFiles([]);
        }
        if (query.contains('daily-sync-v2-event-')) {
          return _driveFiles([
            {
              'id': 'remote-event-1',
              'name': 'daily-sync-v2-event-iphone-all-day.json',
            },
            {
              'id': 'remote-event-2',
              'name': 'daily-sync-v2-event-iphone-all-day-offset.json',
            },
          ]);
        }
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/remote-event-1') {
        return _jsonResponse(
          _eventFileJson(
            id: 'iphone-all-day',
            title: '6.1 평일외출',
            startAt: '2026-06-01T00:00:00.000Z',
            endAt: '2026-06-02T00:00:00.000Z',
          ),
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/remote-event-2') {
        return _jsonResponse(
          _eventFileJson(
            id: 'iphone-all-day-offset',
            title: '6.5 평일외출',
            startAt: '2026-06-05T00:00:00.000+14:00',
            endAt: '2026-06-06T00:00:00.000+14:00',
          ),
        );
      }
      if (request.url.path.startsWith('/upload/drive/v3/files')) {
        fail('restore sync must not upload Google Drive files');
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
    );
    addTearDown(service.dispose);

    await service.restoreNow();

    final saved = {for (final event in repository.events) event.id: event};
    expect(saved['iphone-all-day']!.allDay, isTrue);
    expect(saved['iphone-all-day']!.startAt, DateTime(2026, 6, 1));
    expect(saved['iphone-all-day']!.endAt, DateTime(2026, 6, 2));
    expect(saved['iphone-all-day-offset']!.allDay, isTrue);
    expect(saved['iphone-all-day-offset']!.startAt, DateTime(2026, 6, 5));
    expect(saved['iphone-all-day-offset']!.endAt, DateTime(2026, 6, 6));
    expect(notificationService.scheduled.length, 2);
    expect(notificationService.scheduled.first.startAt, DateTime(2026, 6, 1));
    expect(
      requests.any(
        (request) => request.url.toString().contains('daily-sync-v1'),
      ),
      isFalse,
    );
  });

  test(
    'backup-only event sync uploads only the changed v2 event file',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = _MemoryEventRepository();
      final notificationService = _FakeNotificationService();
      final changed = _event(
        id: 'queued-event',
        title: '6.20~21 캠핑 약속',
        startAt: DateTime(2026, 6, 20),
        endAt: DateTime(2026, 6, 22),
        updatedAt: DateTime(2026, 5, 30, 18),
        syncStatus: 'pending',
      );
      await repository.save(changed);

      final uploadedEventBodies = <Map<String, Object?>>[];
      final requests = <http.Request>[];
      final httpClient = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
          final query = request.url.queryParameters['q'] ?? '';
          if (query.contains('daily-sync-v2-settings.json')) {
            fail('queued event sync must not touch the settings file');
          }
          if (query.contains('daily-sync-v2-event-queued-event.json')) {
            return _driveFiles([
              {
                'id': 'remote-queued-event',
                'name': 'daily-sync-v2-event-queued-event.json',
              },
            ]);
          }
          if (query.contains('name contains')) {
            fail('queued event sync must not list every event file');
          }
        }
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files/remote-queued-event') {
          fail('backup-only event sync must not download the remote event');
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/upload/drive/v3/files/remote-queued-event') {
          uploadedEventBodies.add(
            jsonDecode(request.body) as Map<String, Object?>,
          );
          return _jsonResponse({'id': 'remote-queued-event'});
        }
        return http.Response(
          'unexpected ${request.method} ${request.url}',
          500,
        );
      });

      final service = _service(
        repository: repository,
        notificationService: notificationService,
        preferences: preferences,
        httpClient: httpClient,
      );
      addTearDown(service.dispose);

      await service.backupNow(eventIds: {changed.id});

      expect(uploadedEventBodies, hasLength(1));
      final event = uploadedEventBodies.single['event'] as Map<String, Object?>;
      expect(event['id'], 'queued-event');
      expect(event['startDate'], '2026-06-20');
      expect(event['endDate'], '2026-06-22');
      expect(event['title'], '6.20~21 캠핑 약속');
      expect((await repository.findById('queued-event'))!.syncStatus, 'synced');
      expect(
        requests.any(
          (request) => request.url.toString().contains('daily-sync-v1'),
        ),
        isFalse,
      );
    },
  );

  test('start flushes locally pending v2 event files after restore', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final pending = _event(
      id: 'restart-pending',
      title: '6.30 전역',
      startAt: DateTime(2026, 6, 30),
      endAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 6, 1, 8),
      syncStatus: 'pending',
    );
    await repository.save(pending);

    final uploadedEventBodies = <Map<String, Object?>>[];
    final httpClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
        final query = request.url.queryParameters['q'] ?? '';
        if (query.contains('daily-sync-v2-settings.json')) {
          return _driveFiles([]);
        }
        if (query.contains(
          "name = 'daily-sync-v2-event-restart-pending.json'",
        )) {
          return _driveFiles([
            {
              'id': 'restart-pending-file',
              'name': 'daily-sync-v2-event-restart-pending.json',
            },
          ]);
        }
        if (query.contains('daily-sync-v2-event-')) {
          return _driveFiles([]);
        }
      }
      if (request.method == 'PATCH' &&
          request.url.path == '/upload/drive/v3/files/restart-pending-file') {
        uploadedEventBodies.add(
          jsonDecode(request.body) as Map<String, Object?>,
        );
        return _jsonResponse({'id': 'restart-pending-file'});
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
    );
    addTearDown(service.dispose);

    await service.start();

    expect(uploadedEventBodies, hasLength(1));
    final event = uploadedEventBodies.single['event'] as Map<String, Object?>;
    expect(event['id'], 'restart-pending');
    expect(event['startDate'], '2026-06-30');
    expect(
      (await repository.findById('restart-pending'))!.syncStatus,
      'synced',
    );
  });

  test('pending change flush cancels the delayed event timer', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final changed = _event(
      id: 'queued-before-exit',
      title: '6.6 면회외출',
      startAt: DateTime(2026, 6, 6),
      endAt: DateTime(2026, 6, 7),
      updatedAt: DateTime(2026, 6, 1, 9),
      syncStatus: 'pending',
    );
    await repository.save(changed);

    final uploadedEventBodies = <Map<String, Object?>>[];
    final httpClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
        final query = request.url.queryParameters['q'] ?? '';
        if (query.contains('daily-sync-v2-settings.json')) {
          fail('pending event flush must not touch the settings file');
        }
        if (query.contains(
          "name = 'daily-sync-v2-event-queued-before-exit.json'",
        )) {
          return _driveFiles([
            {
              'id': 'queued-before-exit-file',
              'name': 'daily-sync-v2-event-queued-before-exit.json',
            },
          ]);
        }
        if (query.contains('name contains')) {
          fail('pending event flush must not list every event file');
        }
      }
      if (request.method == 'PATCH' &&
          request.url.path ==
              '/upload/drive/v3/files/queued-before-exit-file') {
        uploadedEventBodies.add(
          jsonDecode(request.body) as Map<String, Object?>,
        );
        return _jsonResponse({'id': 'queued-before-exit-file'});
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
      changeSyncDelay: const Duration(hours: 1),
    );
    addTearDown(service.dispose);

    await service.queueEventUpsert(changed);
    await service.syncPendingChangesNow();
    await Future<void>.delayed(Duration.zero);

    expect(uploadedEventBodies, hasLength(1));
    final event = uploadedEventBodies.single['event'] as Map<String, Object?>;
    expect(event['id'], 'queued-before-exit');
    expect(event['startDate'], '2026-06-06');
    expect(
      (await repository.findById('queued-before-exit'))!.syncStatus,
      'synced',
    );
  });

  test('full sync backs up before restore after the configured gap', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final localEvent = _event(
      id: 'local-event',
      title: 'local first',
      startAt: DateTime(2026, 6, 10),
      endAt: DateTime(2026, 6, 11),
      updatedAt: DateTime(2026, 6, 1, 9),
      syncStatus: 'pending',
    );
    await repository.save(localEvent);

    final requests = <http.Request>[];
    final httpClient = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
        final query = request.url.queryParameters['q'] ?? '';
        if (query.contains('daily-sync-v2-settings.json')) {
          return _driveFiles([]);
        }
        if (query.contains('daily-sync-v2-event-')) {
          return _driveFiles([
            {
              'id': 'local-file',
              'name': 'daily-sync-v2-event-local-event.json',
            },
            {
              'id': 'remote-file',
              'name': 'daily-sync-v2-event-remote-event.json',
            },
          ]);
        }
      }
      if (request.method == 'POST' &&
          request.url.path == '/upload/drive/v3/files') {
        return _jsonResponse({'id': 'settings-file'});
      }
      if (request.method == 'PATCH' &&
          request.url.path == '/upload/drive/v3/files/local-file') {
        return _jsonResponse({'id': 'local-file'});
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/local-file') {
        return _jsonResponse(
          _eventFileJson(
            id: 'local-event',
            title: 'local first',
            startAt: '2026-06-10T00:00:00.000',
            endAt: '2026-06-11T00:00:00.000',
            updatedAt: '2026-06-01T09:00:00.000Z',
          ),
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/drive/v3/files/remote-file') {
        return _jsonResponse(
          _eventFileJson(
            id: 'remote-event',
            title: 'remote after',
            startAt: '2026-06-12T00:00:00.000',
            endAt: '2026-06-13T00:00:00.000',
          ),
        );
      }
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
      backupRestoreDelay: const Duration(milliseconds: 20),
    );
    addTearDown(service.dispose);

    final stopwatch = Stopwatch()..start();
    await service.syncNow();
    stopwatch.stop();

    final uploadIndex = requests.indexWhere(
      (request) =>
          request.method == 'PATCH' &&
          request.url.path == '/upload/drive/v3/files/local-file',
    );
    final restoreDownloadIndex = requests.indexWhere(
      (request) =>
          request.method == 'GET' &&
          request.url.path == '/drive/v3/files/remote-file',
    );
    expect(uploadIndex, isNonNegative);
    expect(restoreDownloadIndex, isNonNegative);
    expect(uploadIndex, lessThan(restoreDownloadIndex));
    expect(
      stopwatch.elapsed,
      greaterThanOrEqualTo(const Duration(milliseconds: 20)),
    );
    expect(await repository.findById('remote-event'), isNotNull);
    expect((await repository.findById('local-event'))!.syncStatus, 'synced');
  });

  test('startListeningOnly does not run an initial restore', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _MemoryEventRepository();
    final notificationService = _FakeNotificationService();
    final requests = <http.Request>[];
    final httpClient = MockClient((request) async {
      requests.add(request);
      return http.Response('unexpected ${request.method} ${request.url}', 500);
    });

    final service = _service(
      repository: repository,
      notificationService: notificationService,
      preferences: preferences,
      httpClient: httpClient,
    );
    addTearDown(service.dispose);

    await service.startListeningOnly();

    expect(requests, isEmpty);
  });

  test(
    'sync asks for Google Drive connection when auth headers are missing',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = _MemoryEventRepository();
      final notificationService = _FakeNotificationService();
      final requests = <http.Request>[];
      final httpClient = MockClient((request) async {
        requests.add(request);
        return http.Response(
          'unexpected ${request.method} ${request.url}',
          500,
        );
      });

      final service = _service(
        authService: _MissingHeaderGoogleDriveAuthService(),
        repository: repository,
        notificationService: notificationService,
        preferences: preferences,
        httpClient: httpClient,
      );
      addTearDown(service.dispose);

      await service.syncNow();

      expect(service.statusNotifier.value.message, 'Google Drive 연결이 필요합니다.');
      expect(requests, isEmpty);
    },
  );
}

GoogleDriveSyncService _service({
  GoogleDriveAuthService? authService,
  required _MemoryEventRepository repository,
  required _FakeNotificationService notificationService,
  required SharedPreferences preferences,
  required http.Client httpClient,
  Duration backupRestoreDelay = Duration.zero,
  Duration changeSyncDelay = Duration.zero,
}) {
  return GoogleDriveSyncService(
    authService: authService ?? _FakeGoogleDriveAuthService(),
    eventRepository: repository,
    notificationService: notificationService,
    settingsRepository: SettingsRepository(preferences: preferences),
    httpClient: httpClient,
    backupRestoreDelay: backupRestoreDelay,
    changeSyncDelay: changeSyncDelay,
  );
}

http.Response _driveFiles(List<Map<String, Object?>> files) {
  return _jsonResponse({'files': files});
}

http.Response _jsonResponse(Map<String, Object?> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Map<String, Object?> _eventFileJson({
  required String id,
  required String title,
  required String startAt,
  required String endAt,
  String updatedAt = '2026-05-29T00:00:00.000Z',
}) {
  return {
    'schemaVersion': 2,
    'type': 'event',
    'event': {
      'id': id,
      'title': title,
      'startAt': startAt,
      'endAt': endAt,
      'allDay': true,
      'category': 'basic',
      'colorValue': EventCategory.basic.colorValue,
      'createdAt': '2026-05-29T00:00:00.000Z',
      'updatedAt': updatedAt,
    },
  };
}

CalendarEvent _event({
  required String id,
  required String title,
  required DateTime startAt,
  required DateTime endAt,
  required DateTime updatedAt,
  String syncStatus = 'synced',
}) {
  return CalendarEvent(
    id: id,
    title: title,
    startAt: startAt,
    endAt: endAt,
    allDay: true,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    syncStatus: syncStatus,
  );
}

class _FakeGoogleDriveAuthService extends GoogleDriveAuthService {
  final _accountChanges = StreamController<GoogleDriveAccount?>.broadcast();

  @override
  Stream<GoogleDriveAccount?> get accountChanges => _accountChanges.stream;

  @override
  GoogleDriveAccount? get currentAccount =>
      const GoogleDriveAccount(email: 'tester@example.com');

  @override
  Future<void> initialize() async {}

  @override
  Future<Map<String, String>?> authorizationHeaders({
    bool promptIfNecessary = false,
  }) async {
    return const {'Authorization': 'Bearer test-token'};
  }
}

class _MissingHeaderGoogleDriveAuthService extends _FakeGoogleDriveAuthService {
  @override
  Future<Map<String, String>?> authorizationHeaders({
    bool promptIfNecessary = false,
  }) async {
    return null;
  }
}

class _FakeNotificationService implements NotificationService {
  final scheduled = <CalendarEvent>[];

  @override
  Future<void> cancelEventReminder(String eventId) async {}

  @override
  Future<void> cancelMorningBriefing() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<int> pendingNotificationCount() async => scheduled.length;

  @override
  Future<String> permissionSummary() async => 'test';

  @override
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  }) async {
    scheduled.add(event);
  }

  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {}

  @override
  Future<void> showTestNotification() async {}
}

class _MemoryEventRepository implements EventRepository {
  final _events = <String, CalendarEvent>{};

  List<CalendarEvent> get events => _events.values.toList();

  @override
  Future<List<CalendarEvent>> allEventsForSync() async => events;

  @override
  Future<void> clearAll() async {
    _events.clear();
  }

  @override
  Future<void> delete(String eventId) async {
    final event = _events[eventId];
    if (event != null) {
      _events[eventId] = event.copyWith(
        deletedAt: DateTime.now(),
        syncStatus: 'pending_delete',
      );
    }
  }

  @override
  Future<CalendarEvent?> findById(String id) async => _events[id];

  @override
  Future<void> hardDelete(String eventId) async {
    _events.remove(eventId);
  }

  @override
  Future<void> markSynced(String eventId) async {
    final event = _events[eventId];
    if (event != null) {
      _events[eventId] = event.copyWith(syncStatus: 'synced');
    }
  }

  @override
  Future<List<CalendarEvent>> pendingSyncEvents() async {
    return _events.values
        .where((event) => event.syncStatus != 'synced')
        .toList();
  }

  @override
  Future<void> save(CalendarEvent event) async {
    _events[event.id] = event.normalizeAllDayBounds();
  }

  @override
  Future<List<CalendarEvent>> search(String query) async => const [];

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    return Stream.value(events);
  }
}
