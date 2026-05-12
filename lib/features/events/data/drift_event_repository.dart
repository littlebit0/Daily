import 'package:drift/drift.dart';

import 'app_database.dart';
import 'event_mapper.dart';
import 'recurrence_expander.dart';
import '../domain/calendar_event.dart';
import '../domain/event_repository.dart';

class DriftEventRepository implements EventRepository {
  DriftEventRepository(this._database, {RecurrenceExpander? expander})
    : _expander = expander ?? RecurrenceExpander();

  final AppDatabase _database;
  final RecurrenceExpander _expander;

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final query = _database.select(_database.eventRecords)
      ..where((table) => table.deletedAt.isNull())
      ..orderBy([(table) => OrderingTerm.asc(table.startAt)]);

    return query.watch().map((records) {
      final events =
          records
              .expand(
                (record) =>
                    _expander.expand(record.toDomain(), rangeStart, rangeEnd),
              )
              .toList()
            ..sort((a, b) => a.startAt.compareTo(b.startAt));
      return events;
    });
  }

  @override
  Future<List<CalendarEvent>> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return const [];
    }

    final rows =
        await (_database.select(_database.eventRecords)
              ..where(
                (table) =>
                    table.deletedAt.isNull() &
                    (table.title.contains(normalized) |
                        table.memo.contains(normalized) |
                        table.location.contains(normalized) |
                        table.category.contains(normalized)),
              )
              ..orderBy([(table) => OrderingTerm.desc(table.startAt)]))
            .get();

    return rows.map((record) => record.toDomain()).toList();
  }

  @override
  Future<List<CalendarEvent>> pendingSyncEvents() async {
    final rows = await (_database.select(
      _database.eventRecords,
    )..where((table) => table.syncStatus.equals('synced').not())).get();

    return rows.map((record) => record.toDomain()).toList();
  }

  @override
  Future<void> save(CalendarEvent event) {
    return _database
        .into(_database.eventRecords)
        .insertOnConflictUpdate(
          EventRecordsCompanion(
            id: Value(event.id),
            title: Value(event.title),
            memo: Value(event.memo),
            location: Value(event.location),
            startAt: Value(event.startAt),
            endAt: Value(event.endAt),
            allDay: Value(event.allDay),
            category: Value(event.category.name),
            colorValue: Value(event.colorValue),
            reminderMinutesBefore: Value(event.reminderMinutesBefore),
            recurrenceFrequency: Value(event.recurrence.frequency.name),
            recurrenceInterval: Value(event.recurrence.interval),
            recurrenceUntil: Value(event.recurrence.until),
            recurrenceCount: Value(event.recurrence.count),
            createdAt: Value(event.createdAt),
            updatedAt: Value(event.updatedAt),
            deletedAt: Value(event.deletedAt),
            deviceId: Value(event.deviceId),
            syncStatus: Value(event.syncStatus),
          ),
        );
  }

  @override
  Future<void> markSynced(String eventId) {
    return (_database.update(_database.eventRecords)
          ..where((table) => table.id.equals(eventId)))
        .write(const EventRecordsCompanion(syncStatus: Value('synced')));
  }

  @override
  Future<void> delete(String eventId) {
    return (_database.update(
      _database.eventRecords,
    )..where((table) => table.id.equals(eventId))).write(
      EventRecordsCompanion(
        deletedAt: Value(DateTime.now()),
        syncStatus: const Value('pending_delete'),
      ),
    );
  }

  @override
  Future<void> hardDelete(String eventId) {
    return (_database.delete(
      _database.eventRecords,
    )..where((table) => table.id.equals(eventId))).go();
  }
}
