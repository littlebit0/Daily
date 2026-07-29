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

class _CountingSyncService implements SyncService {
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
