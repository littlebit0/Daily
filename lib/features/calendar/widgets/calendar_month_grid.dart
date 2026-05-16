import 'dart:math' as math;

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
    final weeks = List.generate(
      6,
      (weekIndex) => days.skip(weekIndex * 7).take(7).toList(),
    );
    final compact = MediaQuery.sizeOf(context).width < 720;
    final maxFlags = compact ? 3 : 8;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xfff6f8fb),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            children: [
              const _WeekdayHeader(),
              Expanded(
                child: Column(
                  children: [
                    for (final week in weeks)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: _WeekRow(
                            month: month,
                            selectedDate: selectedDate,
                            weekDays: week,
                            events: events,
                            maxFlags: maxFlags,
                            onDateSelected: onDateSelected,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DateTime> _visibleDays(DateTime month) {
    final first = DateTime(month.year, month.month);
    final start = first.subtract(Duration(days: first.weekday - 1));
    return List.generate(42, (index) => start.add(Duration(days: index)));
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Row(
        children: labels
            .map(
              (label) => Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xff7c8490),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.month,
    required this.selectedDate,
    required this.weekDays,
    required this.events,
    required this.maxFlags,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final List<DateTime> weekDays;
  final List<CalendarEvent> events;
  final int maxFlags;
  final ValueChanged<DateTime> onDateSelected;

  static const _flagTop = 31.0;
  static const _flagHeight = 20.0;
  static const _flagGap = 3.0;

  @override
  Widget build(BuildContext context) {
    final weekStart = weekDays.first;
    final weekEnd = weekStart.add(const Duration(days: 7));
    final segments = _layoutSegments(weekStart, weekEnd);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 7;
        final usableFlagHeight = math.max(
          0,
          constraints.maxHeight - _flagTop - 18,
        );
        final visibleLanes = math.max(
          1,
          math.min(maxFlags, usableFlagHeight ~/ (_flagHeight + _flagGap)),
        );
        final visibleSegments = segments
            .where((segment) => segment.lane < visibleLanes)
            .toList();
        final overflowCounts = _overflowCounts(segments, visibleLanes);

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Row(
                children: [
                  for (final day in weekDays)
                    Expanded(
                      child: _DayCellBackground(
                        day: day,
                        inMonth: day.month == month.month,
                        selected: _sameDay(day, selectedDate),
                        today: _sameDay(day, DateTime.now()),
                        onTap: () => onDateSelected(day),
                      ),
                    ),
                ],
              ),
              IgnorePointer(
                child: Stack(
                  children: [
                    for (final segment in visibleSegments)
                      Positioned(
                        left: segment.startCol * cellWidth + 5,
                        top: _flagTop + segment.lane * (_flagHeight + _flagGap),
                        width:
                            (segment.endCol - segment.startCol + 1) *
                                cellWidth -
                            10,
                        height: _flagHeight,
                        child: _EventSpanFlag(
                          key: ValueKey(
                            'event-span-${segment.event.id}-${weekStart.year}-${weekStart.month}-${weekStart.day}',
                          ),
                          event: segment.event,
                          segmentStart: weekStart.add(
                            Duration(days: segment.startCol),
                          ),
                        ),
                      ),
                    for (var index = 0; index < overflowCounts.length; index++)
                      if (overflowCounts[index] > 0)
                        Positioned(
                          left: index * cellWidth + 6,
                          bottom: 4,
                          width: cellWidth - 12,
                          child: Text(
                            '+${overflowCounts[index]}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_EventSegment> _layoutSegments(DateTime weekStart, DateTime weekEnd) {
    final rawSegments =
        events
            .where((event) => event.overlaps(weekStart, weekEnd))
            .map((event) => _EventSegment.fromEvent(event, weekStart))
            .where((segment) => segment != null)
            .cast<_EventSegment>()
            .toList()
          ..sort((a, b) {
            final startCompare = a.startCol.compareTo(b.startCol);
            if (startCompare != 0) {
              return startCompare;
            }
            final spanCompare = b.span.compareTo(a.span);
            if (spanCompare != 0) {
              return spanCompare;
            }
            return a.event.startAt.compareTo(b.event.startAt);
          });

    final lanes = <List<_EventSegment>>[];
    final laidOut = <_EventSegment>[];
    for (final segment in rawSegments) {
      var laneIndex = 0;
      while (true) {
        if (laneIndex == lanes.length) {
          lanes.add(<_EventSegment>[]);
        }
        if (_canPlace(lanes[laneIndex], segment)) {
          lanes[laneIndex].add(segment);
          laidOut.add(segment.copyWith(lane: laneIndex));
          break;
        }
        laneIndex += 1;
      }
    }
    return laidOut;
  }

  bool _canPlace(List<_EventSegment> lane, _EventSegment segment) {
    return lane.every(
      (placed) =>
          segment.endCol < placed.startCol || segment.startCol > placed.endCol,
    );
  }

  List<int> _overflowCounts(List<_EventSegment> segments, int visibleLanes) {
    final counts = List.filled(7, 0);
    for (final segment in segments) {
      if (segment.lane < visibleLanes) {
        continue;
      }
      for (var col = segment.startCol; col <= segment.endCol; col++) {
        counts[col] += 1;
      }
    }
    return counts;
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DayCellBackground extends StatelessWidget {
  const _DayCellBackground({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xffeaf2ff) : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.30),
                  width: 1,
                )
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.topLeft,
        child: _DayNumber(day: day, inMonth: inMonth, today: today),
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
      return SizedBox(height: 22, child: child);
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

class _EventSpanFlag extends StatelessWidget {
  const _EventSpanFlag({
    super.key,
    required this.event,
    required this.segmentStart,
  });

  final CalendarEvent event;
  final DateTime segmentStart;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('HH:mm');
    final showTime =
        !event.allDay &&
        event.startAt.year == segmentStart.year &&
        event.startAt.month == segmentStart.month &&
        event.startAt.day == segmentStart.day;
    final prefix = showTime ? '${formatter.format(event.startAt)} ' : '';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color(event.colorValue).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '$prefix${event.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(event.colorValue),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventSegment {
  const _EventSegment({
    required this.event,
    required this.startCol,
    required this.endCol,
    this.lane = 0,
  });

  final CalendarEvent event;
  final int startCol;
  final int endCol;
  final int lane;

  int get span => endCol - startCol + 1;

  static _EventSegment? fromEvent(CalendarEvent event, DateTime weekStart) {
    final eventStart = _dayStart(event.startAt);
    final eventEnd = _inclusiveEndDay(event.endAt);
    final startCol = math.max(0, eventStart.difference(weekStart).inDays);
    final endCol = math.min(6, eventEnd.difference(weekStart).inDays);
    if (endCol < 0 || startCol > 6 || endCol < startCol) {
      return null;
    }
    return _EventSegment(event: event, startCol: startCol, endCol: endCol);
  }

  _EventSegment copyWith({int? lane}) {
    return _EventSegment(
      event: event,
      startCol: startCol,
      endCol: endCol,
      lane: lane ?? this.lane,
    );
  }

  static DateTime _dayStart(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime _inclusiveEndDay(DateTime value) {
    final adjusted = value.subtract(const Duration(microseconds: 1));
    return DateTime(adjusted.year, adjusted.month, adjusted.day);
  }
}
