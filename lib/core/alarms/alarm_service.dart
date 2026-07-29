import '../../features/events/domain/calendar_event.dart';

enum AlarmAuthorizationState { unsupported, notDetermined, denied, authorized }

abstract interface class AlarmService {
  Future<AlarmAuthorizationState> authorizationState();

  Future<AlarmAuthorizationState> requestAuthorization();

  Future<void> scheduleEventAlarm(CalendarEvent event);

  Future<void> cancelEventAlarm(String eventId);

  Future<void> cancelAllEventAlarms();
}

class UnsupportedAlarmService implements AlarmService {
  const UnsupportedAlarmService();

  @override
  Future<AlarmAuthorizationState> authorizationState() async =>
      AlarmAuthorizationState.unsupported;

  @override
  Future<AlarmAuthorizationState> requestAuthorization() async =>
      AlarmAuthorizationState.unsupported;

  @override
  Future<void> scheduleEventAlarm(CalendarEvent event) async {}

  @override
  Future<void> cancelEventAlarm(String eventId) async {}

  @override
  Future<void> cancelAllEventAlarms() async {}
}
