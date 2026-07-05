import '../../features/events/domain/calendar_event.dart';

abstract interface class NotificationService {
  Future<void> initialize();

  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  });

  Future<void> cancelEventReminder(
    String eventId, {
    List<int> reminderMinutesBeforeList = const [],
  });

  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  });

  Future<void> cancelMorningBriefing();

  Future<void> showTestNotification();

  Future<int> pendingNotificationCount();

  Future<String> permissionSummary();
}
