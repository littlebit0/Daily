import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/widgets/apple_widget_service.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'builds month, today, and D-day widget data without sensitive titles',
    () {
      final now = DateTime(2026, 7, 28, 10);
      final events = [
        _event(id: 'meeting', title: '회의', startAt: DateTime(2026, 7, 28, 11)),
        _event(
          id: 'private',
          title: '노출되면 안 되는 일정',
          startAt: DateTime(2026, 7, 28, 13),
          sensitive: true,
        ),
        _event(
          id: 'dday',
          title: '출시',
          startAt: DateTime(2026, 8, 2),
          showDday: true,
        ),
      ];

      final snapshot = AppleWidgetSnapshotBuilder.build(
        now: now,
        settings: AppSettings(),
        gridStart: DateTime(2026, 6, 28),
        monthEvents: events,
        allEvents: events,
      );

      expect(snapshot['weekTitle'], '7월 26일 - 8월 1일');

      final todayEvents = (snapshot['todayEvents']! as List)
          .cast<Map<String, Object?>>();
      expect(todayEvents.map((event) => event['title']), ['회의', '비공개 일정']);
      expect(snapshot.toString(), isNot(contains('노출되면 안 되는 일정')));

      final ddays = (snapshot['ddays']! as List).cast<Map<String, Object?>>();
      expect(ddays.single['title'], '출시');
      expect(ddays.single['daysRemaining'], 5);

      final days = (snapshot['monthDays']! as List)
          .cast<Map<String, Object?>>();
      final today = days.singleWhere((day) => day['date'] == '2026-07-28');
      expect(today['isToday'], isTrue);
      expect(today['eventCount'], 2);
      final monthEvents = (today['events']! as List)
          .cast<Map<String, Object?>>();
      expect(monthEvents.map((event) => event['title']), ['회의', '비공개 일정']);
    },
  );

  test('excludes hidden categories, deleted events, and disabled holidays', () {
    const hidden = EventCategory(
      id: 'hidden',
      label: '숨김',
      colorValue: 0xff000000,
    );
    final now = DateTime(2026, 7, 28);
    final events = [
      _event(id: 'hidden', title: '숨김 일정', startAt: now, category: hidden),
      _event(
        id: 'holiday',
        title: '공휴일',
        startAt: now,
        category: EventCategory.holiday,
        holiday: true,
      ),
      _event(id: 'deleted', title: '삭제 일정', startAt: now, deletedAt: now),
    ];

    final snapshot = AppleWidgetSnapshotBuilder.build(
      now: now,
      settings: AppSettings(
        hiddenCategoryIds: const ['hidden'],
        calendarShowHolidays: false,
      ),
      gridStart: DateTime(2026, 6, 28),
      monthEvents: events,
      allEvents: events,
    );

    expect(snapshot['todayEvents'], isEmpty);
    expect(snapshot['ddays'], isEmpty);
  });

  test('keeps one occurrence id across a continuous multi-day event', () {
    final event = _event(
      id: 'trip',
      title: '여행',
      startAt: DateTime(2026, 7, 27),
      endAt: DateTime(2026, 7, 30),
    );

    final snapshot = AppleWidgetSnapshotBuilder.build(
      now: DateTime(2026, 7, 28),
      settings: AppSettings(),
      gridStart: DateTime(2026, 6, 28),
      monthEvents: [event],
      allEvents: [event],
    );
    final days = (snapshot['monthDays']! as List).cast<Map<String, Object?>>();
    final occurrenceIds = days
        .expand((day) => (day['events']! as List).cast<Map<String, Object?>>())
        .map((event) => event['id'])
        .toList();

    expect(occurrenceIds, ['trip', 'trip', 'trip']);
  });
}

CalendarEvent _event({
  required String id,
  required String title,
  required DateTime startAt,
  DateTime? endAt,
  String? occurrenceId,
  EventCategory category = EventCategory.basic,
  bool showDday = false,
  bool sensitive = false,
  bool holiday = false,
  DateTime? deletedAt,
}) {
  return CalendarEvent(
    id: id,
    occurrenceId: occurrenceId,
    title: title,
    startAt: startAt,
    endAt: endAt ?? startAt.add(const Duration(hours: 1)),
    allDay: false,
    category: category,
    colorValue: category.colorValue,
    createdAt: startAt,
    updatedAt: startAt,
    showDday: showDday,
    sensitive: sensitive,
    holiday: holiday,
    deletedAt: deletedAt,
  );
}
