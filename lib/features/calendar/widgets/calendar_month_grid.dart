import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/calendar/korean_lunar_calendar.dart';
import '../../events/domain/calendar_event.dart';

class CalendarMonthGrid extends StatefulWidget {
  const CalendarMonthGrid({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.events,
    required this.weekStartsOnMonday,
    required this.showLunarDates,
    required this.onDateSelected,
    this.onDateRangeSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final List<CalendarEvent> events;
  final bool weekStartsOnMonday;
  final bool showLunarDates;
  final ValueChanged<DateTime> onDateSelected;
  final Future<void> Function(DateTime start, DateTime end)?
  onDateRangeSelected;

  @override
  State<CalendarMonthGrid> createState() => _CalendarMonthGridState();
}

class _CalendarMonthGridState extends State<CalendarMonthGrid> {
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _mouseRangeActive = false;

  @override
  Widget build(BuildContext context) {
    final days = _visibleDays(widget.month, widget.weekStartsOnMonday);
    final weeks = List.generate(
      6,
      (weekIndex) => days.skip(weekIndex * 7).take(7).toList(),
    );
    final compact = MediaQuery.sizeOf(context).width < 720;
    final maxFlags = compact ? 3 : 8;
    final holidayDays = _holidayDays(widget.events);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xffffffff),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
          child: Column(
            children: [
              _WeekdayHeader(weekStartsOnMonday: widget.weekStartsOnMonday),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Listener(
                    onPointerDown: (event) {
                      if (event.kind != PointerDeviceKind.mouse ||
                          event.buttons != kPrimaryMouseButton) {
                        return;
                      }
                      _mouseRangeActive = true;
                      _startRangeSelection(
                        event.localPosition,
                        days,
                        constraints,
                      );
                    },
                    onPointerMove: (event) {
                      if (!_mouseRangeActive) {
                        return;
                      }
                      if ((event.buttons & kPrimaryMouseButton) == 0) {
                        _mouseRangeActive = false;
                        _finishRangeSelection();
                        return;
                      }
                      _updateRangeSelection(
                        event.localPosition,
                        days,
                        constraints,
                      );
                    },
                    onPointerUp: (event) {
                      if (!_mouseRangeActive) {
                        return;
                      }
                      _mouseRangeActive = false;
                      _finishRangeSelection();
                    },
                    onPointerCancel: (_) {
                      _mouseRangeActive = false;
                      _clearRangeSelection();
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onLongPressStart: (details) => _startRangeSelection(
                        details.localPosition,
                        days,
                        constraints,
                      ),
                      onLongPressMoveUpdate: (details) => _updateRangeSelection(
                        details.localPosition,
                        days,
                        constraints,
                      ),
                      onLongPressEnd: (_) => _finishRangeSelection(),
                      onLongPressCancel: _clearRangeSelection,
                      child: Column(
                        children: [
                          for (final week in weeks)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: _WeekRow(
                                  month: widget.month,
                                  selectedDate: widget.selectedDate,
                                  selectedRangeStart: _rangeStart,
                                  selectedRangeEnd: _rangeEnd,
                                  weekDays: week,
                                  events: widget.events,
                                  maxFlags: maxFlags,
                                  holidayDays: holidayDays,
                                  showLunarDates: widget.showLunarDates,
                                  onDateSelected: widget.onDateSelected,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startRangeSelection(
    Offset position,
    List<DateTime> days,
    BoxConstraints constraints,
  ) {
    final day = _dayAtPosition(position, days, constraints);
    if (day == null) {
      return;
    }
    setState(() {
      _rangeStart = day;
      _rangeEnd = day;
    });
  }

  void _updateRangeSelection(
    Offset position,
    List<DateTime> days,
    BoxConstraints constraints,
  ) {
    if (_rangeStart == null) {
      return;
    }
    final day = _dayAtPosition(position, days, constraints);
    if (day == null || _sameDay(day, _rangeEnd)) {
      return;
    }
    setState(() => _rangeEnd = day);
  }

  void _finishRangeSelection() {
    final start = _rangeStart;
    final end = _rangeEnd;
    _clearRangeSelection();
    if (start == null || end == null) {
      return;
    }
    final normalizedStart = _isAfter(start, end) ? end : start;
    final normalizedEnd = _isAfter(start, end) ? start : end;
    if (_sameDay(normalizedStart, normalizedEnd)) {
      return;
    }
    final callback = widget.onDateRangeSelected;
    if (callback != null) {
      unawaited(callback(normalizedStart, normalizedEnd));
    }
  }

  void _clearRangeSelection() {
    if (_rangeStart == null && _rangeEnd == null) {
      return;
    }
    setState(() {
      _rangeStart = null;
      _rangeEnd = null;
    });
  }

  DateTime? _dayAtPosition(
    Offset position,
    List<DateTime> days,
    BoxConstraints constraints,
  ) {
    if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
      return null;
    }
    final col = (position.dx / (constraints.maxWidth / 7)).floor().clamp(0, 6);
    final row = (position.dy / (constraints.maxHeight / 6)).floor().clamp(0, 5);
    return days[row * 7 + col];
  }

  List<DateTime> _visibleDays(DateTime month, bool weekStartsOnMonday) {
    final first = DateTime(month.year, month.month);
    final leadingDays = weekStartsOnMonday
        ? first.weekday - 1
        : first.weekday % 7;
    final start = first.subtract(Duration(days: leadingDays));
    return List.generate(42, (index) => start.add(Duration(days: index)));
  }

  Set<DateTime> _holidayDays(List<CalendarEvent> events) {
    final days = <DateTime>{};
    for (final event in events.where((event) => event.holiday)) {
      var cursor = DateTime(
        event.startAt.year,
        event.startAt.month,
        event.startAt.day,
      );
      final end = DateTime(
        event.endAt.year,
        event.endAt.month,
        event.endAt.day,
      );
      while (cursor.isBefore(end)) {
        days.add(cursor);
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    return days;
  }

  bool _isAfter(DateTime a, DateTime b) {
    return DateTime(
      a.year,
      a.month,
      a.day,
    ).isAfter(DateTime(b.year, b.month, b.day));
  }

  bool _sameDay(DateTime a, DateTime? b) {
    return b != null &&
        a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.weekStartsOnMonday});

  final bool weekStartsOnMonday;

  @override
  Widget build(BuildContext context) {
    final labels = weekStartsOnMonday
        ? const ['월', '화', '수', '목', '금', '토', '일']
        : const ['일', '월', '화', '수', '목', '금', '토'];
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
                      color: _weekdayColor(label),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Color _weekdayColor(String label) {
    if (label == '일') {
      return const Color(0xffef4444);
    }
    if (label == '토') {
      return const Color(0xff2563eb);
    }
    return const Color(0xff6b7280);
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.month,
    required this.selectedDate,
    required this.selectedRangeStart,
    required this.selectedRangeEnd,
    required this.weekDays,
    required this.events,
    required this.maxFlags,
    required this.holidayDays,
    required this.showLunarDates,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final DateTime? selectedRangeStart;
  final DateTime? selectedRangeEnd;
  final List<DateTime> weekDays;
  final List<CalendarEvent> events;
  final int maxFlags;
  final Set<DateTime> holidayDays;
  final bool showLunarDates;
  final ValueChanged<DateTime> onDateSelected;

  static const _flagTop = 34.0;
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
                        rangeSelected: _inSelectedRange(day),
                        today: _sameDay(day, DateTime.now()),
                        holiday: holidayDays.contains(_dayStart(day)),
                        showLunarDate: showLunarDates,
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
            if (a.event.holiday != b.event.holiday) {
              return a.event.holiday ? -1 : 1;
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

  DateTime _dayStart(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _inSelectedRange(DateTime day) {
    final start = selectedRangeStart;
    final end = selectedRangeEnd;
    if (start == null || end == null) {
      return false;
    }
    final dayStart = _dayStart(day);
    final normalizedStart = _dayStart(start.isAfter(end) ? end : start);
    final normalizedEnd = _dayStart(start.isAfter(end) ? start : end);
    return !dayStart.isBefore(normalizedStart) &&
        !dayStart.isAfter(normalizedEnd);
  }
}

class _DayCellBackground extends StatelessWidget {
  const _DayCellBackground({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.rangeSelected,
    required this.today,
    required this.holiday,
    required this.showLunarDate,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool rangeSelected;
  final bool today;
  final bool holiday;
  final bool showLunarDate;
  final VoidCallback onTap;

  static const _lunarCalendar = KoreanLunarCalendar();

  @override
  Widget build(BuildContext context) {
    final fill = selected
        ? const Color(0xffedf4ff)
        : rangeSelected
        ? const Color(0xffe8f2ff)
        : holiday && inMonth
        ? const Color(0xfffff4f4)
        : Colors.transparent;
    final lunar = showLunarDate ? _lunarCalendar.fromSolar(day) : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.30),
                )
              : rangeSelected
              ? Border.all(color: const Color(0xff93c5fd))
              : null,
        ),
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DayNumber(
              day: day,
              inMonth: inMonth,
              today: today,
              holiday: holiday,
            ),
            if (lunar != null)
              Text(
                lunar.shortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  height: 1.1,
                  color: inMonth
                      ? const Color(0xff9aa3af)
                      : const Color(0xffc7ccd4),
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
    required this.holiday,
  });

  final DateTime day;
  final bool inMonth;
  final bool today;
  final bool holiday;

  @override
  Widget build(BuildContext context) {
    final color = !inMonth
        ? const Color(0xffc2c8d0)
        : today
        ? Colors.white
        : holiday || day.weekday == DateTime.sunday
        ? const Color(0xffef4444)
        : day.weekday == DateTime.saturday
        ? const Color(0xff2563eb)
        : const Color(0xff1f2937);

    final child = Text(
      '${day.day}',
      style: TextStyle(
        fontSize: 12,
        height: 1.1,
        fontWeight: today ? FontWeight.w800 : FontWeight.w700,
        color: color,
      ),
    );

    if (!today) {
      return SizedBox(height: 17, child: child);
    }

    return Container(
      width: 21,
      height: 21,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xff2563eb),
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
    final color = Color(event.colorValue);
    final formatter = DateFormat('HH:mm');
    final showTime =
        !event.allDay &&
        event.startAt.year == segmentStart.year &&
        event.startAt.month == segmentStart.month &&
        event.startAt.day == segmentStart.day;
    final parts = <String>[
      if (event.showDday) _formatDday(event),
      if (showTime) formatter.format(event.startAt),
    ];
    final prefix = parts.isEmpty ? '' : '${parts.join(' · ')}  ';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: event.holiday
            ? color.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
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
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDday(CalendarEvent event) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      event.startAt.year,
      event.startAt.month,
      event.startAt.day,
    );
    final diff = target.difference(today).inDays;
    if (diff == 0) {
      return 'D-day';
    }
    return diff > 0 ? 'D-$diff' : 'D+${diff.abs()}';
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
