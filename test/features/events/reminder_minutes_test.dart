import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes multiple reminder minutes', () {
    expect(normalizeReminderMinutes([30, 10, 30, -1, 0]), [0, 10, 30]);
  });

  test('maps legacy single reminder into the reminder list', () {
    final now = DateTime(2026, 7, 5, 9);
    final event = CalendarEvent(
      id: 'event-1',
      title: '회의',
      startAt: now,
      endAt: now.add(const Duration(hours: 1)),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      reminderMinutesBefore: 30,
      createdAt: now,
      updatedAt: now,
    );

    expect(event.reminderMinutesBeforeList, [30]);
    expect(event.reminderMinutesBefore, 30);
  });

  test('clears reminder list through copyWith', () {
    final now = DateTime(2026, 7, 5, 9);
    final event = CalendarEvent(
      id: 'event-1',
      title: '회의',
      startAt: now,
      endAt: now.add(const Duration(hours: 1)),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      reminderMinutesBeforeList: const [10, 30],
      createdAt: now,
      updatedAt: now,
    );

    final cleared = event.copyWith(clearReminder: true);

    expect(cleared.reminderMinutesBeforeList, isEmpty);
    expect(cleared.reminderMinutesBefore, isNull);
  });
}
