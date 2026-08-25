import 'package:daily/core/calendar/calendar_event_ordering.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const work = EventCategory(id: 'work', label: '업무', colorValue: 0xff2563eb);
  const personal = EventCategory(
    id: 'personal',
    label: '개인',
    colorValue: 0xff10b981,
  );
  final earlyPersonal = _event(
    id: 'personal-early',
    title: '개인 일정',
    hour: 9,
    category: personal,
  );
  final lateWork = _event(
    id: 'work-late',
    title: '업무 일정',
    hour: 18,
    category: work,
  );

  test('category priority follows the saved category order before time', () {
    final sorted = sortedCalendarEvents(
      [earlyPersonal, lateWork],
      priority: CalendarEventSortPriority.category,
      categoryOrder: const ['work', 'personal'],
    );

    expect(sorted.map((event) => event.id), ['work-late', 'personal-early']);
  });

  test('time priority follows start time before category order', () {
    final sorted = sortedCalendarEvents(
      [lateWork, earlyPersonal],
      priority: CalendarEventSortPriority.time,
      categoryOrder: const ['work', 'personal'],
    );

    expect(sorted.map((event) => event.id), ['personal-early', 'work-late']);
  });

  test(
    'identical time and category use title and id as stable tie breakers',
    () {
      final first = _event(id: 'b', title: '가 일정', hour: 9, category: work);
      final second = _event(id: 'a', title: '나 일정', hour: 9, category: work);
      final sorted = sortedCalendarEvents(
        [second, first],
        priority: CalendarEventSortPriority.time,
        categoryOrder: const ['work'],
      );

      expect(sorted.map((event) => event.id), ['b', 'a']);
    },
  );

  test('date-specific manual order overrides the global priority', () {
    final sorted = sortedCalendarEvents(
      [earlyPersonal, lateWork],
      priority: CalendarEventSortPriority.time,
      categoryOrder: const ['work', 'personal'],
      manualOrder: const ['work-late', 'personal-early'],
    );

    expect(sorted.map((event) => event.id), ['work-late', 'personal-early']);
  });

  test('recurring occurrences use their occurrence id for manual order', () {
    final first = earlyPersonal.copyWith(
      occurrenceId: 'personal-early@2026-08-21T09:00:00.000',
    );
    final second = lateWork.copyWith(
      occurrenceId: 'work-late@2026-08-21T18:00:00.000',
    );
    final sorted = sortedCalendarEvents(
      [first, second],
      priority: CalendarEventSortPriority.time,
      categoryOrder: const ['work', 'personal'],
      manualOrder: [
        calendarEventOrderKey(second),
        calendarEventOrderKey(first),
      ],
    );

    expect(sorted.map(calendarEventOrderKey), [
      calendarEventOrderKey(second),
      calendarEventOrderKey(first),
    ]);
  });
}

CalendarEvent _event({
  required String id,
  required String title,
  required int hour,
  required EventCategory category,
}) {
  final start = DateTime(2026, 8, 21, hour);
  return CalendarEvent(
    id: id,
    title: title,
    startAt: start,
    endAt: start.add(const Duration(hours: 1)),
    allDay: false,
    category: category,
    colorValue: category.colorValue,
    createdAt: start,
    updatedAt: start,
  );
}
