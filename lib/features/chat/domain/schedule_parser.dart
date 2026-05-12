import 'event_parse_result.dart';

abstract interface class ScheduleParser {
  Future<EventParseResult> parse(
    String input, {
    required DateTime baseDate,
    DateTime? selectedDate,
    required int defaultReminderMinutes,
  });
}
