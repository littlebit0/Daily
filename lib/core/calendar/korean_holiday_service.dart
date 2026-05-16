import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_category.dart';
import 'korean_lunar_calendar.dart';

class KoreanHoliday {
  const KoreanHoliday({
    required this.date,
    required this.title,
    this.publicHoliday = true,
  });

  final DateTime date;
  final String title;
  final bool publicHoliday;
}

class KoreanHolidayService {
  KoreanHolidayService({KoreanLunarCalendar? lunarCalendar})
    : _lunarCalendar = lunarCalendar ?? const KoreanLunarCalendar();

  final KoreanLunarCalendar _lunarCalendar;

  List<KoreanHoliday> holidaysInRange(DateTime start, DateTime end) {
    final startYear = start.year - 1;
    final endYear = end.year + 1;
    final holidays = <KoreanHoliday>[];
    for (var year = startYear; year <= endYear; year++) {
      holidays.addAll(_holidaysForYear(year));
    }
    return holidays
        .where(
          (holiday) =>
              !holiday.date.isBefore(_dayStart(start)) &&
              holiday.date.isBefore(_dayStart(end)),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<CalendarEvent> holidayEventsInRange(DateTime start, DateTime end) {
    return holidaysInRange(start, end)
        .map(
          (holiday) => CalendarEvent(
            id: 'kr-holiday-${holiday.date.year}-${holiday.date.month}-${holiday.date.day}-${holiday.title}',
            title: holiday.title,
            startAt: holiday.date,
            endAt: holiday.date.add(const Duration(days: 1)),
            allDay: true,
            category: EventCategory.holiday,
            colorValue: EventCategory.holiday.colorValue,
            createdAt: holiday.date,
            updatedAt: holiday.date,
            syncStatus: 'synced',
            readOnly: true,
            systemEvent: true,
            holiday: holiday.publicHoliday,
          ),
        )
        .toList();
  }

  bool isPublicHoliday(DateTime date) {
    final day = _dayStart(date);
    return _holidaysForYear(
      day.year,
    ).any((holiday) => holiday.publicHoliday && _sameDay(holiday.date, day));
  }

  List<KoreanHoliday> _holidaysForYear(int year) {
    final byDate = <DateTime, List<String>>{};
    final substituteGroups = <List<DateTime>>[];
    final singleSubstituteDates = <DateTime>{};

    void add(DateTime date, String title) {
      final day = _dayStart(date);
      byDate.putIfAbsent(day, () => <String>[]).add(title);
    }

    void addFixed(int month, int day, String title, {bool substitute = false}) {
      final date = DateTime(year, month, day);
      add(date, title);
      if (substitute) {
        singleSubstituteDates.add(date);
      }
    }

    addFixed(1, 1, '신정');
    addFixed(3, 1, '삼일절', substitute: true);
    if (year >= 2027) {
      addFixed(5, 1, '노동절', substitute: true);
    }
    addFixed(5, 5, '어린이날', substitute: true);
    addFixed(6, 6, '현충일');
    if (year >= 2026) {
      addFixed(7, 17, '제헌절', substitute: true);
    }
    addFixed(8, 15, '광복절', substitute: true);
    addFixed(10, 3, '개천절', substitute: true);
    addFixed(10, 9, '한글날', substitute: true);
    addFixed(12, 25, '기독탄신일', substitute: true);

    final lunarNewYear = _lunarCalendar.toSolar(year: year, month: 1, day: 1);
    if (lunarNewYear != null) {
      final group = [
        lunarNewYear.subtract(const Duration(days: 1)),
        lunarNewYear,
        lunarNewYear.add(const Duration(days: 1)),
      ];
      add(group[0], '설날 연휴');
      add(group[1], '설날');
      add(group[2], '설날 연휴');
      substituteGroups.add(group);
    }

    final buddhaBirthday = _lunarCalendar.toSolar(year: year, month: 4, day: 8);
    if (buddhaBirthday != null) {
      add(buddhaBirthday, '부처님 오신 날');
      singleSubstituteDates.add(buddhaBirthday);
    }

    final chuseok = _lunarCalendar.toSolar(year: year, month: 8, day: 15);
    if (chuseok != null) {
      final group = [
        chuseok.subtract(const Duration(days: 1)),
        chuseok,
        chuseok.add(const Duration(days: 1)),
      ];
      add(group[0], '추석 연휴');
      add(group[1], '추석');
      add(group[2], '추석 연휴');
      substituteGroups.add(group);
    }

    final occupied = byDate.keys.toSet();
    for (final date in singleSubstituteDates) {
      final day = _dayStart(date);
      final overlapsOtherHoliday = (byDate[day]?.length ?? 0) > 1;
      if (_isWeekend(day) || overlapsOtherHoliday) {
        final substitute = _nextAvailableBusinessDay(
          day.add(const Duration(days: 1)),
          occupied,
        );
        add(substitute, '대체공휴일');
        occupied.add(substitute);
      }
    }

    for (final group in substituteGroups) {
      final needsSubstitute =
          group.any((date) => date.weekday == DateTime.sunday) ||
          group.any((date) => (byDate[_dayStart(date)]?.length ?? 0) > 1);
      if (needsSubstitute) {
        final substitute = _nextAvailableBusinessDay(
          group.last.add(const Duration(days: 1)),
          occupied,
        );
        add(substitute, '대체공휴일');
        occupied.add(substitute);
      }
    }

    return byDate.entries
        .map(
          (entry) => KoreanHoliday(
            date: entry.key,
            title: entry.value.toSet().join(' · '),
          ),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  DateTime _nextAvailableBusinessDay(DateTime start, Set<DateTime> occupied) {
    var candidate = _dayStart(start);
    while (_isWeekend(candidate) || occupied.contains(candidate)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _dayStart(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
