import 'package:daily/core/alarms/alarm_service.dart';
import 'package:daily/core/analytics/product_analytics.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'category appearance updates skip OS notification rescheduling',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final previous = EventCategory.basic;
      const updated = EventCategory(
        id: 'basic',
        label: '기본 일정',
        colorValue: 0xff123456,
      );
      final affected = [_event('one', previous), _event('two', previous)];
      final repository = _CategoryUpdateRepository(affected);
      final notifications = _CountingNotificationService();
      final sync = _CountingSyncService();
      var widgetRefreshes = 0;
      final service = EventCommandService(
        repository: repository,
        settingsRepository: SettingsRepository(preferences: preferences),
        notificationService: notifications,
        syncService: sync,
        onEventsChanged: () async => widgetRefreshes += 1,
      );

      await service.updateCategoryUsage(previous: previous, updated: updated);

      expect(notifications.cancelCalls, 0);
      expect(notifications.scheduleCalls, 0);
      expect(sync.upsertedIds, ['one', 'two']);
      expect(widgetRefreshes, 1);
    },
  );

  test(
    'Todo completion persists, syncs, and updates scheduled delivery',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = _CompletionRepository(
        _event('todo', EventCategory.basic),
      );
      final notifications = _CountingNotificationService();
      final alarms = _CountingAlarmService();
      final sync = _CountingSyncService();
      final analytics = _RecordingAnalytics();
      var widgetRefreshes = 0;
      final service = EventCommandService(
        repository: repository,
        settingsRepository: SettingsRepository(preferences: preferences),
        notificationService: notifications,
        alarmService: alarms,
        syncService: sync,
        analytics: analytics,
        onEventsChanged: () async => widgetRefreshes += 1,
      );

      await service.setCompleted(repository.event, true);

      expect(repository.event.completed, isTrue);
      expect(repository.event.syncStatus, 'pending');
      expect(notifications.cancelCalls, 1);
      expect(notifications.scheduleCalls, 0);
      expect(alarms.cancelCalls, 1);
      expect(alarms.scheduleCalls, 0);

      await service.setCompleted(repository.event, false);

      expect(repository.event.completed, isFalse);
      expect(notifications.cancelCalls, 2);
      expect(notifications.scheduleCalls, 1);
      expect(alarms.cancelCalls, 2);
      expect(alarms.scheduleCalls, 1);
      expect(sync.upsertedIds, ['todo', 'todo']);
      expect(widgetRefreshes, 2);
      expect(
        analytics.records.map((record) => record.attributes['operation']),
        ['complete', 'uncomplete'],
      );
    },
  );

  test('analytics failure never changes an event command result', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _CompletionRepository(
      _event('isolated', EventCategory.basic),
    );
    final service = EventCommandService(
      repository: repository,
      settingsRepository: SettingsRepository(preferences: preferences),
      notificationService: _CountingNotificationService(),
      alarmService: _CountingAlarmService(),
      syncService: _CountingSyncService(),
      analytics: const _ThrowingAnalytics(),
    );

    await service.setCompleted(repository.event, true);
    await Future<void>.delayed(Duration.zero);

    expect(repository.event.completed, isTrue);
  });
}

CalendarEvent _event(String id, EventCategory category) {
  final start = DateTime(2026, 7, 29, 9);
  return CalendarEvent(
    id: id,
    title: id,
    startAt: start,
    endAt: start.add(const Duration(hours: 1)),
    allDay: false,
    category: category,
    colorValue: category.colorValue,
    createdAt: start,
    updatedAt: start,
  );
}

class _CategoryUpdateRepository implements EventRepository {
  _CategoryUpdateRepository(this.affected);

  final List<CalendarEvent> affected;

  @override
  Future<List<CalendarEvent>> updateCategoryReferences({
    required EventCategory previous,
    required EventCategory updated,
    required DateTime updatedAt,
  }) async {
    return affected
        .map(
          (event) => event.copyWith(
            category: updated,
            colorValue: updated.colorValue,
            updatedAt: updatedAt,
          ),
        )
        .toList();
  }

  @override
  Future<List<CalendarEvent>> allEventsForSync() async => const [];

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> delete(String eventId) async {}

  @override
  Future<List<CalendarEvent>> eventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async => const [];

  @override
  Future<CalendarEvent?> findById(String id) async => null;

  @override
  Future<void> hardDelete(String eventId) async {}

  @override
  Future<void> markSynced(String eventId) async {}

  @override
  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> remoteEvents, {
    required RestoredEventResolver resolve,
  }) async => const [];

  @override
  Future<List<CalendarEvent>> pendingSyncEvents() async => const [];

  @override
  Future<void> save(CalendarEvent event) async {}

  @override
  Future<List<CalendarEvent>> search(String query) async => const [];

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) => const Stream.empty();
}

class _CountingNotificationService implements NotificationService {
  var cancelCalls = 0;
  var scheduleCalls = 0;

  @override
  Future<void> cancelEventReminder(
    String eventId, {
    List<int> reminderMinutesBeforeList = const [],
  }) async {
    cancelCalls += 1;
  }

  @override
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  }) async {
    scheduleCalls += 1;
  }

  @override
  Future<void> cancelMorningBriefing() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<int> pendingNotificationCount() async => 0;

  @override
  Future<String> permissionSummary() async => '';

  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {}

  @override
  Future<void> showTestNotification() async {}
}

class _CountingAlarmService implements AlarmService {
  var cancelCalls = 0;
  var scheduleCalls = 0;

  @override
  Future<AlarmAuthorizationState> authorizationState() async =>
      AlarmAuthorizationState.authorized;

  @override
  Future<void> cancelAllEventAlarms() async {}

  @override
  Future<void> cancelEventAlarm(String eventId) async => cancelCalls += 1;

  @override
  Future<AlarmAuthorizationState> requestAuthorization() async =>
      AlarmAuthorizationState.authorized;

  @override
  Future<void> scheduleEventAlarm(CalendarEvent event) async =>
      scheduleCalls += 1;
}

class _CompletionRepository implements EventRepository {
  _CompletionRepository(this.event);

  CalendarEvent event;

  @override
  Future<CalendarEvent?> findById(String id) async =>
      event.id == id ? event : null;

  @override
  Future<void> save(CalendarEvent value) async => event = value;

  @override
  Future<List<CalendarEvent>> allEventsForSync() async => [event];

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> delete(String eventId) async {}

  @override
  Future<List<CalendarEvent>> eventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async => [event];

  @override
  Future<void> hardDelete(String eventId) async {}

  @override
  Future<void> markSynced(String eventId) async {}

  @override
  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> remoteEvents, {
    required RestoredEventResolver resolve,
  }) async => const [];

  @override
  Future<List<CalendarEvent>> pendingSyncEvents() async => [event];

  @override
  Future<List<CalendarEvent>> search(String query) async => [event];

  @override
  Future<List<CalendarEvent>> updateCategoryReferences({
    required EventCategory previous,
    required EventCategory updated,
    required DateTime updatedAt,
  }) async => const [];

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) => Stream.value([event]);
}

class _CountingSyncService implements SyncService {
  @override
  Future<void> queueSettingsBackup() async {}

  final upsertedIds = <String>[];

  @override
  Future<void> queueEventDelete(String eventId) async {}

  @override
  Future<void> queueEventUpsert(CalendarEvent event) async {
    upsertedIds.add(event.id);
  }

  @override
  Future<void> start() async {}
}

class _RecordingAnalytics extends NoopProductAnalytics {
  final records = <AnalyticsRecord>[];

  @override
  Future<void> record(AnalyticsRecord record) async => records.add(record);
}

class _ThrowingAnalytics extends NoopProductAnalytics {
  const _ThrowingAnalytics();

  @override
  Future<void> record(AnalyticsRecord record) async {
    throw StateError('analytics unavailable');
  }
}
