import '../../features/events/domain/calendar_event.dart';

abstract interface class NotificationService {
  Future<void> initialize();

  Future<void> scheduleEventReminder(CalendarEvent event);

  Future<void> cancelEventReminder(String eventId);

  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  });
}
