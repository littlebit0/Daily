import '../../events/domain/event_category.dart';
import '../../events/domain/event_draft.dart';
import '../../events/domain/recurrence_rule.dart';
import '../domain/event_parse_result.dart';
import '../domain/schedule_parser.dart';

class RuleBasedScheduleParser implements ScheduleParser {
  static final _monthDayPattern = RegExp(r'(\d{1,2})\s*월\s*(\d{1,2})\s*일');
  static final _timePattern = RegExp(
    r'(오전|오후|아침|점심|저녁|밤)?\s*(\d{1,2})(?:\s*시|:)(?:\s*(\d{1,2})\s*분?)?',
  );
  static final _hourReminderPattern = RegExp(r'(\d{1,2})\s*시간\s*전');
  static final _minuteReminderPattern = RegExp(r'(\d{1,3})\s*분\s*전');

  @override
  Future<EventParseResult> parse(
    String input, {
    required DateTime baseDate,
    DateTime? selectedDate,
    required int defaultReminderMinutes,
  }) async {
    final normalized = input.trim();
    if (normalized.isEmpty) {
      return const EventParseResult(question: '등록할 일정 내용을 입력해 주세요.');
    }

    final date = _parseDate(normalized, baseDate, selectedDate);
    final parsedTime = _parseTime(normalized);
    final reminder = _parseReminder(normalized) ?? defaultReminderMinutes;
    final recurrence = _parseRecurrence(normalized);
    final title = _cleanTitle(normalized);
    final category = EventCategory.classify(normalized);

    final startAt = parsedTime == null
        ? DateTime(date.year, date.month, date.day)
        : DateTime(
            date.year,
            date.month,
            date.day,
            parsedTime.hour,
            parsedTime.minute,
          );
    final endAt = parsedTime == null
        ? startAt.add(const Duration(days: 1))
        : startAt.add(const Duration(hours: 1));

    return EventParseResult(
      draft: EventDraft(
        title: title.isEmpty ? '새 일정' : title,
        startAt: startAt,
        endAt: endAt,
        allDay: parsedTime == null,
        category: category,
        colorValue: category.colorValue,
        reminderMinutesBefore: parsedTime == null ? null : reminder,
        recurrence: recurrence,
      ),
    );
  }

  DateTime _parseDate(String input, DateTime baseDate, DateTime? selectedDate) {
    final today = DateTime(baseDate.year, baseDate.month, baseDate.day);
    if (input.contains('모레')) {
      return today.add(const Duration(days: 2));
    }
    if (input.contains('내일')) {
      return today.add(const Duration(days: 1));
    }
    if (input.contains('오늘')) {
      return today;
    }

    final monthDay = _monthDayPattern.firstMatch(input);
    if (monthDay != null) {
      final month = int.parse(monthDay.group(1)!);
      final day = int.parse(monthDay.group(2)!);
      var year = today.year;
      final date = DateTime(year, month, day);
      if (date.isBefore(today.subtract(const Duration(days: 1)))) {
        year += 1;
      }
      return DateTime(year, month, day);
    }

    final weekday = _parseWeekday(input);
    if (weekday != null) {
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      final isNextWeek = input.contains('다음 주') || input.contains('다음주');
      final candidate = startOfWeek.add(
        Duration(days: weekday - 1 + (isNextWeek ? 7 : 0)),
      );
      if (!isNextWeek && candidate.isBefore(today)) {
        return candidate.add(const Duration(days: 7));
      }
      return candidate;
    }

    if (selectedDate != null) {
      return DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    }
    return today;
  }

  _ParsedTime? _parseTime(String input) {
    final match = _timePattern.firstMatch(input);
    if (match == null) {
      return null;
    }

    final marker = match.group(1);
    var hour = int.parse(match.group(2)!);
    final minute = int.tryParse(match.group(3) ?? '') ?? 0;

    final isPm =
        marker == '오후' || marker == '저녁' || marker == '밤' || marker == '점심';
    final isAm = marker == '오전' || marker == '아침';

    if (isPm && hour < 12) {
      hour += 12;
    }
    if (isAm && hour == 12) {
      hour = 0;
    }
    if (hour > 23 || minute > 59) {
      return null;
    }
    return _ParsedTime(hour, minute);
  }

  int? _parseReminder(String input) {
    final hour = _hourReminderPattern.firstMatch(input);
    if (hour != null) {
      return int.parse(hour.group(1)!) * 60;
    }
    final minute = _minuteReminderPattern.firstMatch(input);
    if (minute != null) {
      return int.parse(minute.group(1)!);
    }
    return null;
  }

  RecurrenceRule _parseRecurrence(String input) {
    final frequency = switch (input) {
      final text when text.contains('매일') => RecurrenceFrequency.daily,
      final text when text.contains('매주') => RecurrenceFrequency.weekly,
      final text when text.contains('매월') => RecurrenceFrequency.monthly,
      final text when text.contains('매년') => RecurrenceFrequency.yearly,
      _ => RecurrenceFrequency.none,
    };
    return RecurrenceRule(frequency: frequency);
  }

  int? _parseWeekday(String input) {
    const weekdays = {
      '월': DateTime.monday,
      '화': DateTime.tuesday,
      '수': DateTime.wednesday,
      '목': DateTime.thursday,
      '금': DateTime.friday,
      '토': DateTime.saturday,
      '일': DateTime.sunday,
    };
    for (final entry in weekdays.entries) {
      if (input.contains('${entry.key}요일')) {
        return entry.value;
      }
    }
    return null;
  }

  String _cleanTitle(String input) {
    var value = input;
    final removalPatterns = [
      _monthDayPattern,
      _timePattern,
      _hourReminderPattern,
      _minuteReminderPattern,
      RegExp(r'오늘|내일|모레|이번 주|이번주|다음 주|다음주'),
      RegExp(r'월요일|화요일|수요일|목요일|금요일|토요일|일요일'),
      RegExp(r'매일|매주|매월|매년'),
      RegExp(r'알림|일정|등록|넣어줘|추가해줘|잡아줘|해줘'),
      RegExp(r'[,，]'),
    ];
    for (final pattern in removalPatterns) {
      value = value.replaceAll(pattern, ' ');
    }
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class _ParsedTime {
  const _ParsedTime(this.hour, this.minute);

  final int hour;
  final int minute;
}
