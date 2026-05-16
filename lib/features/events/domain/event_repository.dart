import 'calendar_event.dart';

abstract interface class EventRepository {
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  );

  Future<List<CalendarEvent>> search(String query);

  Future<List<CalendarEvent>> pendingSyncEvents();

  Future<List<CalendarEvent>> allEventsForSync();

  Future<void> save(CalendarEvent event);

  Future<void> markSynced(String eventId);

  Future<void> delete(String eventId);

  Future<void> hardDelete(String eventId);

  Future<void> clearAll();
}
