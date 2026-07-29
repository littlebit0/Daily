import 'package:daily/core/calendar_import/calendar_import_models.dart';
import 'package:daily/core/calendar_import/calendar_import_service.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarImportService.externalEventId', () {
    ExternalCalendarEvent event({
      String sourceId = 'event-1',
      String calendarId = 'calendar-1',
      CalendarImportProvider provider = CalendarImportProvider.google,
    }) {
      return ExternalCalendarEvent(
        sourceId: sourceId,
        calendarId: calendarId,
        provider: provider,
        title: '일정',
        startAt: DateTime(2026, 7, 29, 9),
        endAt: DateTime(2026, 7, 29, 10),
        allDay: false,
      );
    }

    test('같은 외부 일정은 항상 같은 Daily ID를 만든다', () {
      expect(
        CalendarImportService.externalEventId(event()),
        CalendarImportService.externalEventId(event()),
      );
    });

    test('공급자, 캘린더 또는 원본 ID가 다르면 Daily ID도 다르다', () {
      final base = CalendarImportService.externalEventId(event());
      expect(
        CalendarImportService.externalEventId(
          event(provider: CalendarImportProvider.apple),
        ),
        isNot(base),
      );
      expect(
        CalendarImportService.externalEventId(event(calendarId: 'other')),
        isNot(base),
      );
      expect(
        CalendarImportService.externalEventId(event(sourceId: 'other')),
        isNot(base),
      );
    });
  });

  test('가져온 캘린더 분류 ID는 공급자와 원본 캘린더별로 안정적이다', () {
    const apple = ImportableCalendar(
      id: 'calendar-1',
      title: '회사',
      provider: CalendarImportProvider.apple,
      colorValue: 0xff123456,
    );
    const google = ImportableCalendar(
      id: 'calendar-1',
      title: '회사',
      provider: CalendarImportProvider.google,
      colorValue: 0xff123456,
    );

    expect(
      CalendarImportService.importedCategoryId(apple),
      CalendarImportService.importedCategoryId(apple),
    );
    expect(
      CalendarImportService.importedCategoryId(apple),
      isNot(CalendarImportService.importedCategoryId(google)),
    );
  });

  group('CalendarImportService.recurrenceFromRrule', () {
    test('빈 값은 반복 없음으로 변환한다', () {
      expect(
        CalendarImportService.recurrenceFromRrule(null).frequency,
        RecurrenceFrequency.none,
      );
    });

    test('주간 반복의 간격과 횟수를 보존한다', () {
      final rule = CalendarImportService.recurrenceFromRrule(
        'RRULE:FREQ=WEEKLY;INTERVAL=2;COUNT=8',
      );
      expect(rule.frequency, RecurrenceFrequency.weekly);
      expect(rule.interval, 2);
      expect(rule.count, 8);
    });

    test('UTC 종료 시각을 로컬 DateTime으로 변환한다', () {
      final rule = CalendarImportService.recurrenceFromRrule(
        'FREQ=DAILY;UNTIL=20260731T000000Z',
      );
      expect(rule.frequency, RecurrenceFrequency.daily);
      expect(rule.until, DateTime.utc(2026, 7, 31).toLocal());
    });
  });
}
