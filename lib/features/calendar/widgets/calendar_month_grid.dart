import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../events/domain/calendar_event.dart';

class CalendarMonthGrid extends StatelessWidget {
  const CalendarMonthGrid({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.events,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final days = _visibleDays(month);
    final compact = MediaQuery.sizeOf(context).width < 720;
    final maxFlags = compact ? 3 : 8;

    return Column(
      children: [
        const _WeekdayHeader(),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.95,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              final dayEvents = _eventsForDay(day);
              return _DayCell(
                day: day,
                inMonth: day.month == month.month,
                selected: _sameDay(day, selectedDate),
                today: _sameDay(day, DateTime.now()),
                events: dayEvents,
                maxFlags: maxFlags,
                onTap: () => onDateSelected(day),
              );
            },
          ),
        ),
      ],
    );
  }

  List<CalendarEvent> _eventsForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return events
        .where(
          (event) => event.startAt.isBefore(end) && event.endAt.isAfter(start),
        )
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  List<DateTime> _visibleDays(DateTime month) {
    final first = DateTime(month.year, month.month);
    final start = first.subtract(Duration(days: first.weekday - 1));
    return List.generate(42, (index) => start.add(Duration(days: index)));
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: labels
            .map(
              (label) => Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.events,
    required this.maxFlags,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool today;
  final List<CalendarEvent> events;
  final int maxFlags;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visible = events.take(maxFlags).toList();
    final overflow = events.length - visible.length;
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).dividerColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xffeef4ff) : Colors.white,
          border: Border.all(color: borderColor, width: selected ? 1.4 : 0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DayNumber(day: day, inMonth: inMonth, today: today),
            const SizedBox(height: 4),
            Expanded(
              child: Column(
                children: [
                  for (final event in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: _EventFlag(event: event),
                    ),
                  if (overflow > 0)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '+$overflow',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayNumber extends StatelessWidget {
  const _DayNumber({
    required this.day,
    required this.inMonth,
    required this.today,
  });

  final DateTime day;
  final bool inMonth;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final color = !inMonth
        ? const Color(0xffb2b7c0)
        : today
        ? Colors.white
        : const Color(0xff22262d);

    final child = Text(
      '${day.day}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: today ? FontWeight.w700 : FontWeight.w600,
        color: color,
      ),
    );

    if (!today) {
      return child;
    }

    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xff2f6fed),
      ),
      child: child,
    );
  }
}

class _EventFlag extends StatelessWidget {
  const _EventFlag({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('HH:mm');
    final prefix = event.allDay ? '' : '${formatter.format(event.startAt)} ';
    return Container(
      width: double.infinity,
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Color(event.colorValue).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
        border: Border(
          left: BorderSide(color: Color(event.colorValue), width: 3),
        ),
      ),
      child: Text(
        '$prefix${event.title}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(event.colorValue),
        ),
      ),
    );
  }
}
