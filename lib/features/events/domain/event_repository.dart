import 'calendar_event.dart';
import 'event_category.dart';

typedef RestoredEventResolver =
    CalendarEvent Function(CalendarEvent? local, CalendarEvent remote);

class EventRestoreMutation {
  const EventRestoreMutation({required this.previous, required this.current});

  final CalendarEvent? previous;
  final CalendarEvent current;
}

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

  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> remoteEvents, {
    required RestoredEventResolver resolve,
  });

  Future<void> save(CalendarEvent event);

  Future<void> saveAllAtomically(Iterable<CalendarEvent> events);

  Future<void> markSynced(String eventId);

  Future<void> delete(String eventId);

  Future<void> hardDelete(String eventId);

  Future<void> clearAll();
}
