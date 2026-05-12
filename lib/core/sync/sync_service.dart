import '../../features/events/domain/calendar_event.dart';

abstract interface class SyncService {
  Future<void> start();

  Future<void> queueEventUpsert(CalendarEvent event);

  Future<void> queueEventDelete(String eventId);
}
