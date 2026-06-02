import 'package:daily/features/calendar/widgets/calendar_month_grid.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps today and lunar day labels on the same row', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final neighbor = today.weekday == DateTime.sunday
        ? today.subtract(const Duration(days: 1))
        : today.add(const Duration(days: 1));
    final event = CalendarEvent(
      id: 'single',
      title: '일정',
      startAt: today,
      endAt: today.add(const Duration(days: 1)),
      allDay: true,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: today,
      updatedAt: today,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 420,
            child: CalendarMonthGrid(
              month: DateTime(today.year, today.month),
              selectedDate: today,
              events: [event],
              weekStartsOnMonday: true,
              showLunarDates: true,
              density: CalendarDensity.standard,
              hideSensitiveEvents: false,
              onDateSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    final todayNumber = find.byKey(
      ValueKey('day-number-${today.year}-${today.month}-${today.day}'),
    );
    final neighborNumber = find.byKey(
      ValueKey('day-number-${neighbor.year}-${neighbor.month}-${neighbor.day}'),
    );
    final flag = find.byKey(
      ValueKey(
        'event-span-single-${_weekStart(today).year}-${_weekStart(today).month}-${_weekStart(today).day}',
      ),
    );

    expect(todayNumber, findsOneWidget);
    expect(neighborNumber, findsOneWidget);
    expect(flag, findsOneWidget);
    expect(
      tester.getTopLeft(todayNumber).dy,
      closeTo(tester.getTopLeft(neighborNumber).dy, 0.1),
    );
    expect(
      tester.getTopLeft(flag).dy - tester.getBottomLeft(todayNumber).dy,
      lessThan(8),
    );
  });

  testWidgets('renders a multi-day event as one spanning flag in a week row', (
    tester,
  ) async {
    final now = DateTime(2026, 5, 1);
    final event = CalendarEvent(
      id: 'trip',
      title: '부산 여행',
      startAt: DateTime(2026, 5, 4),
      endAt: DateTime(2026, 5, 8),
      allDay: true,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 420,
            child: CalendarMonthGrid(
              month: DateTime(2026, 5),
              selectedDate: DateTime(2026, 5, 4),
              events: [event],
              weekStartsOnMonday: true,
              showLunarDates: true,
              density: CalendarDensity.standard,
              hideSensitiveEvents: false,
              onDateSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    final flag = find.byKey(const ValueKey('event-span-trip-2026-5-4'));
    expect(flag, findsOneWidget);
    expect(find.text('부산 여행'), findsOneWidget);
    expect(tester.getSize(flag).width, greaterThan(300));
  });
}

DateTime _weekStart(DateTime day) {
  return DateTime(
    day.year,
    day.month,
    day.day,
  ).subtract(Duration(days: day.weekday - DateTime.monday));
}
