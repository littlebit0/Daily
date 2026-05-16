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

    test('parses an all-day multi-day event', () async {
      final result = await parser.parse(
        '5월 20일부터 5월 22일까지 부산 여행',
        baseDate: baseDate,
        defaultReminderMinutes: 60,
      );

      final draft = result.draft!;
      expect(draft.title, '부산 여행');
      expect(draft.startAt, DateTime(2026, 5, 20));
      expect(draft.endAt, DateTime(2026, 5, 23));
      expect(draft.allDay, isTrue);
      expect(draft.reminderMinutesBefore, isNull);
    });

    test('parses a timed multi-day event', () async {
      final result = await parser.parse(
        '5월 20일 오후 2시부터 5월 22일 오전 10시까지 출장',
        baseDate: baseDate,
        defaultReminderMinutes: 60,
      );

      final draft = result.draft!;
      expect(draft.title, '출장');
      expect(draft.startAt, DateTime(2026, 5, 20, 14));
      expect(draft.endAt, DateTime(2026, 5, 22, 10));
      expect(draft.allDay, isFalse);
    });

    test('parses a duration-based multi-day event', () async {
      final result = await parser.parse(
        '내일부터 3일간 워크숍',
        baseDate: baseDate,
        defaultReminderMinutes: 60,
      );

      final draft = result.draft!;
      expect(draft.title, '워크숍');
      expect(draft.startAt, DateTime(2026, 5, 12));
      expect(draft.endAt, DateTime(2026, 5, 15));
      expect(draft.allDay, isTrue);
    });
  });
}
