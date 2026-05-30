import 'dart:convert';

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
                        table.url.contains(normalized) |
                        table.weather.contains(normalized) |
                        table.category.contains(normalized)),
              )
              ..orderBy([(table) => OrderingTerm.desc(table.startAt)]))
            .get();

    return rows.map((record) => record.toDomain()).toList();
  }

  @override
  Future<CalendarEvent?> findById(String id) async {
    final row = await (_database.select(
      _database.eventRecords,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<List<CalendarEvent>> pendingSyncEvents() async {
    final rows = await (_database.select(
      _database.eventRecords,
    )..where((table) => table.syncStatus.equals('synced').not())).get();

    return rows.map((record) => record.toDomain()).toList();
  }

  @override
  Future<List<CalendarEvent>> allEventsForSync() async {
    final rows = await (_database.select(
      _database.eventRecords,
    )..orderBy([(table) => OrderingTerm.asc(table.updatedAt)])).get();

    return rows.map((record) => record.toDomain()).toList();
  }

  @override
  Future<void> save(CalendarEvent event) {
    final normalized = event.normalizeAllDayBounds();
    return _database
        .into(_database.eventRecords)
        .insertOnConflictUpdate(
          EventRecordsCompanion(
            id: Value(normalized.id),
            title: Value(normalized.title),
            memo: Value(normalized.memo),
            location: Value(normalized.location),
            url: Value(normalized.url),
            weather: Value(normalized.weather),
            startAt: Value(normalized.startAt),
            endAt: Value(normalized.endAt),
            allDay: Value(normalized.allDay),
            category: Value(_storedCategoryValue(normalized)),
            colorValue: Value(normalized.colorValue),
            reminderMinutesBefore: Value(normalized.reminderMinutesBefore),
            recurrenceFrequency: Value(normalized.recurrence.frequency.name),
            recurrenceInterval: Value(normalized.recurrence.interval),
            recurrenceUntil: Value(normalized.recurrence.until),
            recurrenceCount: Value(normalized.recurrence.count),
            recurrenceExcludedDates: Value(
              jsonEncode(
                normalized.recurrence.excludedDates
                    .map((date) => DateTime(date.year, date.month, date.day))
                    .map((date) => date.toIso8601String())
                    .toList(),
              ),
            ),
            createdAt: Value(normalized.createdAt),
            updatedAt: Value(normalized.updatedAt),
            deletedAt: Value(normalized.deletedAt),
            deviceId: Value(normalized.deviceId),
            syncStatus: Value(normalized.syncStatus),
            showDday: Value(normalized.showDday),
            sensitive: Value(normalized.sensitive),
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

  @override
  Future<void> clearAll() {
    return _database.delete(_database.eventRecords).go();
  }

  String _storedCategoryValue(CalendarEvent event) {
    if (event.category.id == 'basic' || event.category.id == 'holiday') {
      return event.category.id;
    }
    return event.category.label;
  }
}
