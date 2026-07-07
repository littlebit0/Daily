import 'calendar_event.dart';
import 'event_category.dart';

abstract interface class EventRepository {
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  );

  Future<List<CalendarEvent>> eventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  );

  Future<List<CalendarEvent>> search(String query);

  Future<CalendarEvent?> findById(String id);

  Future<List<CalendarEvent>> pendingSyncEvents();

  Future<List<CalendarEvent>> allEventsForSync();

  Future<List<CalendarEvent>> updateCategoryReferences({
    required EventCategory previous,
    required EventCategory updated,
    required DateTime updatedAt,
  });

  Future<void> save(CalendarEvent event);

  Future<void> markSynced(String eventId);

  Future<void> delete(String eventId);

  Future<void> hardDelete(String eventId);

  Future<void> clearAll();
}
