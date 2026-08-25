import 'package:daily/features/calendar/widgets/schedule_timeline_view.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/theme/event_completion_style.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('all-day area is absent when there are no all-day events', (
    tester,
  ) async {
    await _pumpAllDaySchedule(tester, eventCount: 0);

    expect(find.byKey(const ValueKey('schedule-all-day-area')), findsNothing);
  });

  testWidgets('all-day area height follows visible event rows', (tester) async {
    await _pumpAllDaySchedule(tester, eventCount: 1);
    final oneEventHeight = tester
        .getSize(find.byKey(const ValueKey('schedule-all-day-area')))
        .height;

    await _pumpAllDaySchedule(tester, eventCount: 3);
    final threeEventHeight = tester
        .getSize(find.byKey(const ValueKey('schedule-all-day-area')))
        .height;

    await _pumpAllDaySchedule(tester, eventCount: 6);
    final sixEventHeight = tester
        .getSize(find.byKey(const ValueKey('schedule-all-day-area')))
        .height;

    expect(threeEventHeight, greaterThan(oneEventHeight));
    expect(sixEventHeight, greaterThan(threeEventHeight));
    expect(sixEventHeight, lessThan(130));
    expect(find.text('종일 일정 6'), findsOneWidget);
    expect(find.text('+2'), findsNothing);
  });

  testWidgets('all-day area grows with the app text scale', (tester) async {
    await _pumpAllDaySchedule(tester, eventCount: 4, textScale: 1);
    final basicHeight = tester
        .getSize(find.byKey(const ValueKey('schedule-all-day-area')))
        .height;

    await _pumpAllDaySchedule(tester, eventCount: 4, textScale: 1.15);
    final largeHeight = tester
        .getSize(find.byKey(const ValueKey('schedule-all-day-area')))
        .height;

    await _pumpAllDaySchedule(tester, eventCount: 4, textScale: 1.3);
    final extraLargeHeight = tester
        .getSize(find.byKey(const ValueKey('schedule-all-day-area')))
        .height;

    expect(largeHeight, greaterThan(basicHeight));
    expect(extraLargeHeight, greaterThan(basicHeight));
    expect(extraLargeHeight, greaterThan(largeHeight));
  });

  testWidgets('week all-day overflow remains reachable by internal scroll', (
    tester,
  ) async {
    await _pumpAllDaySchedule(tester, eventCount: 6, weekMode: true);

    final allDayScroll = find.byKey(const ValueKey('schedule-all-day-scroll'));
    final scrollable = find.descendant(
      of: allDayScroll,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));

    await tester.drag(allDayScroll, const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(0));
    expect(find.text('종일 일정 6'), findsOneWidget);
  });

  testWidgets('week schedule colors weekends and holidays', (tester) async {
    final days = List.generate(7, (index) => DateTime(2026, 8, 23 + index));
    final holiday = CalendarEvent(
      id: 'holiday',
      title: '공휴일',
      startAt: DateTime(2026, 8, 27),
      endAt: DateTime(2026, 8, 28),
      allDay: true,
      category: EventCategory.holiday,
      colorValue: EventCategory.holiday.colorValue,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
      holiday: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: ScheduleTimelineView(
            days: days,
            events: [holiday],
            selectedDate: DateTime(2026, 8, 24),
            use24HourTime: true,
            showAllDayEvents: true,
            holidayBackgroundEnabled: true,
            holidayColorValue: 0xffef4444,
            onShowAllDayEventsChanged: (_) {},
            onDateSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _headerColor(tester, DateTime(2026, 8, 23)),
      const Color(0xffef4444),
    );
    expect(
      _headerColor(tester, DateTime(2026, 8, 24)),
      ThemeData.light().colorScheme.onPrimaryContainer,
    );
    expect(
      _headerColor(tester, DateTime(2026, 8, 27)),
      const Color(0xffef4444),
    );
    expect(
      _headerColor(tester, DateTime(2026, 8, 29)),
      const Color(0xff2563eb),
    );
  });

  testWidgets('day schedule keeps weekend color when the day is not selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: ScheduleTimelineView(
            days: [DateTime(2026, 8, 23)],
            events: const [],
            selectedDate: DateTime(2026, 8, 24),
            use24HourTime: true,
            showAllDayEvents: true,
            holidayBackgroundEnabled: true,
            holidayColorValue: 0xffef4444,
            onShowAllDayEventsChanged: (_) {},
            onDateSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _headerColor(tester, DateTime(2026, 8, 23)),
      const Color(0xffef4444),
    );
  });

  testWidgets(
    'monday-start week keeps calendar weekdays and selected weekend priority',
    (tester) async {
      final theme = ThemeData.dark();
      final days = List.generate(7, (index) => DateTime(2026, 8, 24 + index));

      await tester.pumpWidget(
        MaterialApp(
          darkTheme: theme,
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: ScheduleTimelineView(
              days: days,
              events: const [],
              selectedDate: DateTime(2026, 8, 29),
              use24HourTime: true,
              showAllDayEvents: true,
              holidayBackgroundEnabled: true,
              holidayColorValue: 0xffef4444,
              onShowAllDayEventsChanged: (_) {},
              onDateSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        _headerColor(tester, DateTime(2026, 8, 29)),
        theme.colorScheme.onPrimaryContainer,
      );
      expect(
        _headerColor(tester, DateTime(2026, 8, 30)),
        const Color(0xffef4444),
      );
    },
  );

  testWidgets('schedule holiday keeps weekend text without a red background', (
    tester,
  ) async {
    const holidayColor = Color(0xff10b981);
    final holiday = CalendarEvent(
      id: 'holiday',
      title: '공휴일',
      startAt: DateTime(2026, 8, 27),
      endAt: DateTime(2026, 8, 28),
      allDay: true,
      category: EventCategory.holiday.copyWith(
        colorValue: holidayColor.toARGB32(),
      ),
      colorValue: holidayColor.toARGB32(),
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
      holiday: true,
    );

    Future<void> pump({required bool enabled}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: ScheduleTimelineView(
              days: [DateTime(2026, 8, 27)],
              events: [holiday],
              selectedDate: DateTime(2026, 8, 26),
              use24HourTime: true,
              showAllDayEvents: true,
              holidayBackgroundEnabled: enabled,
              holidayColorValue: holidayColor.toARGB32(),
              onShowAllDayEventsChanged: (_) {},
              onDateSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(enabled: true);
    expect(
      _headerBackgroundColor(tester, DateTime(2026, 8, 27)),
      Colors.transparent,
    );

    await pump(enabled: false);
    expect(
      _headerBackgroundColor(tester, DateTime(2026, 8, 27)),
      Colors.transparent,
    );
  });

  testWidgets('schedule all-day titles honor center alignment', (tester) async {
    final event = CalendarEvent(
      id: 'alignment',
      title: '정렬 테스트',
      startAt: DateTime(2026, 8, 27),
      endAt: DateTime(2026, 8, 28),
      allDay: true,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleTimelineView(
            days: [DateTime(2026, 8, 27)],
            events: [event],
            selectedDate: DateTime(2026, 8, 27),
            use24HourTime: true,
            showAllDayEvents: true,
            holidayBackgroundEnabled: true,
            holidayColorValue: EventCategory.holiday.colorValue,
            centerEventTitles: true,
            onShowAllDayEventsChanged: (_) {},
            onDateSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text('정렬 테스트')).textAlign,
      TextAlign.center,
    );
  });

  testWidgets('completed schedule event uses a visible double strike', (
    tester,
  ) async {
    final event = CalendarEvent(
      id: 'completed-schedule',
      title: '완료 일정',
      startAt: DateTime(2026, 8, 27),
      endAt: DateTime(2026, 8, 28),
      allDay: true,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
      completed: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: ScheduleTimelineView(
            days: [DateTime(2026, 8, 27)],
            events: [event],
            selectedDate: DateTime(2026, 8, 27),
            use24HourTime: true,
            showAllDayEvents: true,
            holidayBackgroundEnabled: true,
            holidayColorValue: EventCategory.holiday.colorValue,
            onShowAllDayEventsChanged: (_) {},
            onDateSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final style = tester.widget<Text>(find.text('완료 일정')).style!;
    expect(style.decoration, TextDecoration.lineThrough);
    expect(style.decorationStyle, TextDecorationStyle.double);
    expect(style.decorationThickness, greaterThanOrEqualTo(2));
    final eventContainer = tester.widget<Container>(
      find
          .ancestor(of: find.text('완료 일정'), matching: find.byType(Container))
          .first,
    );
    expect(
      (eventContainer.decoration! as BoxDecoration).color,
      calendarCompletedEventBackgroundColor(tester.element(find.text('완료 일정'))),
    );
  });

  testWidgets('schedule event can be long-pressed and dropped on another day', (
    tester,
  ) async {
    final event = CalendarEvent(
      id: 'move-schedule',
      title: '이동 일정',
      startAt: DateTime(2026, 8, 27),
      endAt: DateTime(2026, 8, 28),
      allDay: true,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );
    DateTime? droppedDate;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleTimelineView(
            days: [DateTime(2026, 8, 27), DateTime(2026, 8, 28)],
            events: [event],
            selectedDate: DateTime(2026, 8, 27),
            use24HourTime: true,
            showAllDayEvents: true,
            holidayBackgroundEnabled: true,
            holidayColorValue: EventCategory.holiday.colorValue,
            onEventDropped: (event, date, index) async {
              droppedDate = date;
            },
            onShowAllDayEventsChanged: (_) {},
            onDateSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('이동 일정')),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final target = find.byKey(
      const ValueKey('schedule-day-background-2026-8-28'),
    );
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 120));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(droppedDate, DateTime(2026, 8, 28));
  });

  testWidgets('overlapping schedule lanes follow category order', (
    tester,
  ) async {
    const work = EventCategory(id: 'work', label: '업무', colorValue: 0xff2563eb);
    const personal = EventCategory(
      id: 'personal',
      label: '개인',
      colorValue: 0xff10b981,
    );
    CalendarEvent event(String id, EventCategory category) {
      return CalendarEvent(
        id: id,
        title: id,
        startAt: DateTime(2026, 8, 27, 9),
        endAt: DateTime(2026, 8, 27, 11),
        allDay: false,
        category: category,
        colorValue: category.colorValue,
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      );
    }

    Future<void> pump(List<String> categoryOrder) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScheduleTimelineView(
              days: [DateTime(2026, 8, 27)],
              events: [event('personal', personal), event('work', work)],
              selectedDate: DateTime(2026, 8, 27),
              use24HourTime: true,
              showAllDayEvents: true,
              holidayBackgroundEnabled: true,
              holidayColorValue: EventCategory.holiday.colorValue,
              eventSortPriority: CalendarEventSortPriority.category,
              categoryOrder: categoryOrder,
              onShowAllDayEventsChanged: (_) {},
              onDateSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final workFinder = find.byKey(
      ValueKey(
        'schedule-event-work-${DateTime(2026, 8, 27).toIso8601String()}',
      ),
    );
    final personalFinder = find.byKey(
      ValueKey(
        'schedule-event-personal-${DateTime(2026, 8, 27).toIso8601String()}',
      ),
    );

    await pump(const ['work', 'personal']);
    expect(
      tester.getTopLeft(workFinder).dx,
      lessThan(tester.getTopLeft(personalFinder).dx),
    );

    await pump(const ['personal', 'work']);
    expect(
      tester.getTopLeft(personalFinder).dx,
      lessThan(tester.getTopLeft(workFinder).dx),
    );
  });
}

Future<void> _pumpAllDaySchedule(
  WidgetTester tester, {
  required int eventCount,
  double textScale = 1,
  bool weekMode = false,
}) async {
  final events = List.generate(
    eventCount,
    (index) => CalendarEvent(
      id: 'all-day-$index',
      title: '종일 일정 ${index + 1}',
      startAt: DateTime(2026, 8, 27),
      endAt: DateTime(2026, 8, 28),
      allDay: true,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: ScheduleTimelineView(
          days: weekMode
              ? List.generate(7, (index) => DateTime(2026, 8, 23 + index))
              : [DateTime(2026, 8, 27)],
          events: events,
          selectedDate: DateTime(2026, 8, 27),
          use24HourTime: true,
          showAllDayEvents: true,
          holidayBackgroundEnabled: true,
          holidayColorValue: EventCategory.holiday.colorValue,
          onShowAllDayEventsChanged: (_) {},
          onDateSelected: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color? _headerColor(WidgetTester tester, DateTime day) {
  final text = tester.widget<Text>(
    find.byKey(
      ValueKey('schedule-day-header-${day.year}-${day.month}-${day.day}'),
    ),
  );
  return text.style?.color;
}

Color? _headerBackgroundColor(WidgetTester tester, DateTime day) {
  final container = tester.widget<Container>(
    find.byKey(
      ValueKey('schedule-day-background-${day.year}-${day.month}-${day.day}'),
    ),
  );
  return (container.decoration! as BoxDecoration).color;
}
