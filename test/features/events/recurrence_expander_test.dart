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

  test('includes the until date for timed daily recurrences', () {
    final occurrences = RecurrenceExpander().expand(
      _recurringEvent(
        startAt: DateTime(2026, 8, 24, 9),
        endAt: DateTime(2026, 8, 24, 10),
        recurrence: RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          until: DateTime(2026, 8, 26),
        ),
      ),
      DateTime(2026, 8, 1),
      DateTime(2026, 9, 1),
    );

    expect(occurrences.map((event) => event.startAt.day), [24, 25, 26]);
  });

  test('includes the until date for all-day daily recurrences', () {
    final occurrences = RecurrenceExpander().expand(
      _recurringEvent(
        startAt: DateTime(2026, 8, 24),
        endAt: DateTime(2026, 8, 25),
        allDay: true,
        recurrence: RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          until: DateTime(2026, 8, 26),
        ),
      ),
      DateTime(2026, 8, 1),
      DateTime(2026, 9, 1),
    );

    expect(occurrences.map((event) => event.startAt.day), [24, 25, 26]);
  });

  test('includes the until date across a year boundary and stops after it', () {
    final occurrences = RecurrenceExpander().expand(
      _recurringEvent(
        startAt: DateTime(2026, 12, 30, 23, 30),
        endAt: DateTime(2026, 12, 31, 0, 30),
        recurrence: RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          until: DateTime(2027, 1, 1),
        ),
      ),
      DateTime(2026, 12, 1),
      DateTime(2027, 2, 1),
    );

    expect(occurrences.map((event) => event.startAt), [
      DateTime(2026, 12, 30, 23, 30),
      DateTime(2026, 12, 31, 23, 30),
      DateTime(2027, 1, 1, 23, 30),
    ]);
  });

  test(
    'includes matching until dates for every supported recurrence period',
    () {
      final cases =
          <
            ({
              RecurrenceFrequency frequency,
              DateTime start,
              DateTime until,
              List<DateTime> expected,
            })
          >[
            (
              frequency: RecurrenceFrequency.weekly,
              start: DateTime(2026, 8, 12, 9),
              until: DateTime(2026, 8, 26),
              expected: [
                DateTime(2026, 8, 12, 9),
                DateTime(2026, 8, 19, 9),
                DateTime(2026, 8, 26, 9),
              ],
            ),
            (
              frequency: RecurrenceFrequency.monthly,
              start: DateTime(2026, 10, 26, 9),
              until: DateTime(2027, 1, 26),
              expected: [
                DateTime(2026, 10, 26, 9),
                DateTime(2026, 11, 26, 9),
                DateTime(2026, 12, 26, 9),
                DateTime(2027, 1, 26, 9),
              ],
            ),
            (
              frequency: RecurrenceFrequency.yearly,
              start: DateTime(2024, 8, 26, 9),
              until: DateTime(2026, 8, 26),
              expected: [
                DateTime(2024, 8, 26, 9),
                DateTime(2025, 8, 26, 9),
                DateTime(2026, 8, 26, 9),
              ],
            ),
          ];

      for (final testCase in cases) {
        final occurrences = RecurrenceExpander().expand(
          _recurringEvent(
            startAt: testCase.start,
            endAt: testCase.start.add(const Duration(hours: 1)),
            recurrence: RecurrenceRule(
              frequency: testCase.frequency,
              until: testCase.until,
            ),
          ),
          DateTime(2024),
          DateTime(2028),
        );

        expect(
          occurrences.map((event) => event.startAt),
          testCase.expected,
          reason: testCase.frequency.name,
        );
      }
    },
  );
}

CalendarEvent _recurringEvent({
  required DateTime startAt,
  required DateTime endAt,
  required RecurrenceRule recurrence,
  bool allDay = false,
}) {
  return CalendarEvent(
    id: 'recurrence-${recurrence.frequency.name}-${startAt.toIso8601String()}',
    title: '반복 일정',
    startAt: startAt,
    endAt: endAt,
    allDay: allDay,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    recurrence: recurrence,
    createdAt: startAt,
    updatedAt: startAt,
  );
}
