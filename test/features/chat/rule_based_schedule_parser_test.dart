import 'package:daily/features/chat/application/rule_based_schedule_parser.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleBasedScheduleParser', () {
    final parser = RuleBasedScheduleParser();
    final baseDate = DateTime(2026, 5, 11);

    test('parses a simple timed event with the default reminder', () async {
      final result = await parser.parse(
        '내일 오후 3시 병원',
        baseDate: baseDate,
        defaultReminderMinutes: 60,
      );

      final draft = result.draft!;
      expect(draft.title, '병원');
      expect(draft.startAt, DateTime(2026, 5, 12, 15));
      expect(draft.endAt, DateTime(2026, 5, 12, 16));
      expect(draft.reminderMinutesBefore, 60);
      expect(draft.category, EventCategory.health);
    });

    test('uses a selected date when no date is typed', () async {
      final result = await parser.parse(
        '오전 9시 회의',
        baseDate: baseDate,
        selectedDate: DateTime(2026, 5, 20),
        defaultReminderMinutes: 60,
      );

      expect(result.draft!.startAt, DateTime(2026, 5, 20, 9));
    });

    test('parses recurring events', () async {
      final result = await parser.parse(
        '매주 월요일 오후 7시 운동',
        baseDate: baseDate,
        defaultReminderMinutes: 60,
      );

      expect(result.draft!.recurrence.frequency, RecurrenceFrequency.weekly);
    });
  });
}
