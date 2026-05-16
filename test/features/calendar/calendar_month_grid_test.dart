import 'package:daily/features/calendar/widgets/calendar_month_grid.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      category: EventCategory.travel,
      colorValue: EventCategory.travel.colorValue,
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
