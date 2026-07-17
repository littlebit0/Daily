import 'package:daily/features/calendar/widgets/calendar_month_grid.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter/gestures.dart';
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

  testWidgets('uses fixed iPhone-width event capacity in month cells', (
    tester,
  ) async {
    await _expectVisibleEventFlags(
      tester,
      width: 375,
      height: 812,
      expectedVisible: 4,
    );
    await _expectVisibleEventFlags(
      tester,
      width: 430,
      height: 932,
      expectedVisible: 5,
    );
    await _expectVisibleEventFlags(
      tester,
      width: 440,
      height: 956,
      expectedVisible: 6,
    );
  });

  testWidgets('selects a date range with a primary mouse drag', (tester) async {
    final now = DateTime(2026, 5, 1);
    final holiday = CalendarEvent(
      id: 'holiday',
      title: '공휴일',
      startAt: DateTime(2026, 5, 6),
      endAt: DateTime(2026, 5, 7),
      allDay: true,
      category: EventCategory.holiday,
      colorValue: EventCategory.holiday.colorValue,
      createdAt: now,
      updatedAt: now,
      readOnly: true,
      systemEvent: true,
      holiday: true,
    );
    DateTime? selectedStart;
    DateTime? selectedEnd;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 420,
            child: CalendarMonthGrid(
              month: DateTime(2026, 5),
              selectedDate: DateTime(2026, 5, 1),
              events: [holiday],
              weekStartsOnMonday: true,
              showLunarDates: false,
              hideSensitiveEvents: false,
              onDateSelected: (_) {},
              onDateRangeSelected: (start, end) async {
                selectedStart = start;
                selectedEnd = end;
              },
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(_dayNumberKey(DateTime(2026, 5, 4))),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(tester.getCenter(_dayNumberKey(DateTime(2026, 5, 8))));
    await tester.pump();

    final rangeHighlight = find.byKey(
      const ValueKey('selected-range-2026-5-4'),
    );
    expect(rangeHighlight, findsOneWidget);
    expect(tester.getSize(rangeHighlight).width, greaterThan(400));
    final holidayCell = tester.widget<Container>(
      find.byKey(const ValueKey('day-cell-2026-5-6')),
    );
    final holidayCellDecoration = holidayCell.decoration! as BoxDecoration;
    expect(holidayCellDecoration.color, Colors.transparent);

    await gesture.up();
    await tester.pump();

    expect(selectedStart, DateTime(2026, 5, 4));
    expect(selectedEnd, DateTime(2026, 5, 8));
  });

  testWidgets('locked sensitive month event hides title, time, and D-day', (
    tester,
  ) async {
    final event = CalendarEvent(
      id: 'private-event',
      title: '비밀 약속',
      startAt: DateTime(2026, 5, 4, 10),
      endAt: DateTime(2026, 5, 4, 11),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      showDday: true,
      sensitive: true,
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
              showLunarDates: false,
              hideSensitiveEvents: true,
              onDateSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('비공개 일정'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.textContaining('비밀 약속'), findsNothing);
    expect(find.textContaining('10:00'), findsNothing);
    expect(find.textContaining('D-'), findsNothing);
  });

  test('defines the requested full-app text scale choices', () {
    expect(AppTextSize.basic.scale, 0.8);
    expect(AppTextSize.large.scale, 1.0);
  });
}

DateTime _weekStart(DateTime day) {
  return DateTime(
    day.year,
    day.month,
    day.day,
  ).subtract(Duration(days: day.weekday - DateTime.monday));
}

Finder _dayNumberKey(DateTime day) {
  return find.byKey(ValueKey('day-number-${day.year}-${day.month}-${day.day}'));
}

Future<void> _expectVisibleEventFlags(
  WidgetTester tester, {
  required double width,
  required double height,
  required int expectedVisible,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final now = DateTime(2026, 5, 1);
  final events = List.generate(
    7,
    (index) => CalendarEvent(
      id: 'density-$index',
      title: '일정 ${index + 1}',
      startAt: DateTime(2026, 5, 4, 9 + index),
      endAt: DateTime(2026, 5, 4, 10 + index),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: now,
      updatedAt: now,
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, height)),
        child: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: CalendarMonthGrid(
              month: DateTime(2026, 5),
              selectedDate: DateTime(2026, 5, 4),
              events: events,
              weekStartsOnMonday: true,
              showLunarDates: true,
              hideSensitiveEvents: false,
              onDateSelected: (_) {},
            ),
          ),
        ),
      ),
    ),
  );

  for (var index = 0; index < expectedVisible; index++) {
    expect(
      find.byKey(ValueKey('event-span-density-$index-2026-5-4')),
      findsOneWidget,
      reason: '$width px should show event lane ${index + 1}.',
    );
  }
  expect(
    find.byKey(ValueKey('event-span-density-$expectedVisible-2026-5-4')),
    findsNothing,
    reason: '$width px should overflow after $expectedVisible visible events.',
  );
  final lastVisibleFlag = find.byKey(
    ValueKey('event-span-density-${expectedVisible - 1}-2026-5-4'),
  );
  final overflowLabel = find.text('+${events.length - expectedVisible}');
  expect(overflowLabel, findsOneWidget);
  expect(
    tester.getTopLeft(overflowLabel).dy,
    greaterThanOrEqualTo(tester.getBottomLeft(lastVisibleFlag).dy),
    reason: '$width px overflow label should not overlap visible events.',
  );
}
