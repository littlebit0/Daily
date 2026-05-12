import '../domain/calendar_event.dart';
import '../domain/recurrence_rule.dart';

class RecurrenceExpander {
  List<CalendarEvent> expand(
    CalendarEvent event,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    if (!event.recurrence.isRepeating) {
      return event.overlaps(rangeStart, rangeEnd) ? [event] : const [];
    }

    final occurrences = <CalendarEvent>[];
    final duration = event.endAt.difference(event.startAt);
    var current = event.startAt;
    var generated = 0;
    final until = event.recurrence.until;
    final maxCount = event.recurrence.count;

    while (current.isBefore(rangeEnd)) {
      generated += 1;
      if (until != null && current.isAfter(until)) {
        break;
      }
      if (maxCount != null && generated > maxCount) {
        break;
      }

      final occurrenceEnd = current.add(duration);
      if (current.isBefore(rangeEnd) && occurrenceEnd.isAfter(rangeStart)) {
        occurrences.add(
          event.copyWith(
            occurrenceId: '${event.id}@${current.toIso8601String()}',
            startAt: current,
            endAt: occurrenceEnd,
          ),
        );
      }

      final next = _next(current, event.recurrence);
      if (!next.isAfter(current)) {
        break;
      }
      current = next;
    }

    return occurrences;
  }

  DateTime _next(DateTime current, RecurrenceRule rule) {
    final interval = rule.interval < 1 ? 1 : rule.interval;
    return switch (rule.frequency) {
      RecurrenceFrequency.none => current,
      RecurrenceFrequency.daily => current.add(Duration(days: interval)),
      RecurrenceFrequency.weekly => current.add(Duration(days: 7 * interval)),
      RecurrenceFrequency.monthly => _addMonths(current, interval),
      RecurrenceFrequency.yearly => _addYears(current, interval),
    };
  }

  DateTime _addMonths(DateTime value, int months) {
    final targetMonth = value.month + months;
    final targetYear = value.year + ((targetMonth - 1) ~/ 12);
    final normalizedMonth = ((targetMonth - 1) % 12) + 1;
    final day = value.day.clamp(1, _daysInMonth(targetYear, normalizedMonth));
    return DateTime(
      targetYear,
      normalizedMonth,
      day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  DateTime _addYears(DateTime value, int years) {
    final targetYear = value.year + years;
    final day = value.day.clamp(1, _daysInMonth(targetYear, value.month));
    return DateTime(
      targetYear,
      value.month,
      day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
}
