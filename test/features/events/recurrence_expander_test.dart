import 'package:daily/features/events/data/recurrence_expander.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expands weekly events inside the visible range', () {
    final event = CalendarEvent(
      id: 'event-1',
      title: '운동',
      startAt: DateTime(2026, 5, 4, 19),
      endAt: DateTime(2026, 5, 4, 20),
      allDay: false,
      category: EventCategory.health,
      colorValue: EventCategory.health.colorValue,
      recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.weekly),
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );

    final occurrences = RecurrenceExpander().expand(
      event,
      DateTime(2026, 5, 1),
      DateTime(2026, 6, 1),
    );

    expect(occurrences.map((event) => event.startAt.day), [4, 11, 18, 25]);
  });

  test('fast-forwards an old daily recurrence to the visible range', () {
    final event = CalendarEvent(
      id: 'old-daily',
      title: '매일 기록',
      startAt: DateTime(2000, 1, 1, 9),
      endAt: DateTime(2000, 1, 1, 10),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.daily),
      createdAt: DateTime(2000, 1, 1),
      updatedAt: DateTime(2000, 1, 1),
    );

    final occurrences = RecurrenceExpander().expand(
      event,
      DateTime(2026, 7, 1),
      DateTime(2026, 7, 4),
    );

    expect(occurrences.map((occurrence) => occurrence.startAt), [
      DateTime(2026, 7, 1, 9),
      DateTime(2026, 7, 2, 9),
      DateTime(2026, 7, 3, 9),
    ]);
  });

  test('fast-forward preserves recurrence count semantics', () {
    final event = CalendarEvent(
      id: 'finished-daily',
      title: '완료된 반복',
      startAt: DateTime(2000, 1, 1, 9),
      endAt: DateTime(2000, 1, 1, 10),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      recurrence: const RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        count: 30,
      ),
      createdAt: DateTime(2000, 1, 1),
      updatedAt: DateTime(2000, 1, 1),
    );

    final occurrences = RecurrenceExpander().expand(
      event,
      DateTime(2026, 7, 1),
      DateTime(2026, 8, 1),
    );

    expect(occurrences, isEmpty);
  });
}
