import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/calendar/korean_lunar_calendar.dart';
import '../../../core/settings/app_settings.dart';
import '../../events/domain/calendar_event.dart';

class CalendarMonthGrid extends StatefulWidget {
  const CalendarMonthGrid({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.events,
    required this.weekStartsOnMonday,
    required this.showLunarDates,
    required this.density,
    required this.hideSensitiveEvents,
    required this.onDateSelected,
    this.onDateRangeSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final List<CalendarEvent> events;
  final bool weekStartsOnMonday;
  final bool showLunarDates;
  final CalendarDensity density;
  final bool hideSensitiveEvents;
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
  bool _longPressRangeActive = false;

  @override
  Widget build(BuildContext context) {
    final days = _visibleDays(widget.month, widget.weekStartsOnMonday);
    final weeks = List.generate(
      days.length ~/ 7,
      (weekIndex) => days.skip(weekIndex * 7).take(7).toList(),
    );
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    final maxFlags = _maxFlagsForDensity(widget.density, width: width);
    final holidayDays = _holidayDays(widget.events);

    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(4, 0, 4, 8)
          : const EdgeInsets.fromLTRB(12, 0, 12, 10),
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
          padding: compact
              ? const EdgeInsets.fromLTRB(3, 6, 3, 6)
              : const EdgeInsets.fromLTRB(8, 7, 8, 8),
          child: Column(
            children: [
              _WeekdayHeader(weekStartsOnMonday: widget.weekStartsOnMonday),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Listener(
                    onPointerDown: (event) {
                      if (!_isDesktopRangePointer(event.kind) ||
                          !_hasPrimaryButton(event.buttons)) {
                        return;
                      }
                      _mouseRangeActive = true;
                      _longPressRangeActive = false;
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
                      if (!_mouseRangeActive && !_longPressRangeActive) {
                        return;
                      }
                      _mouseRangeActive = false;
                      _longPressRangeActive = false;
                      _clearRangeSelection();
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onLongPressStart: (details) {
                        if (_mouseRangeActive) {
                          return;
                        }
                        _longPressRangeActive = true;
                        _startRangeSelection(
                          details.localPosition,
                          days,
                          constraints,
                        );
                      },
                      onLongPressMoveUpdate: (details) {
                        if (!_longPressRangeActive) {
                          return;
                        }
                        _updateRangeSelection(
                          details.localPosition,
                          days,
                          constraints,
                        );
                      },
                      onLongPressEnd: (_) {
                        if (!_longPressRangeActive) {
                          return;
                        }
                        _longPressRangeActive = false;
                        _finishRangeSelection();
                      },
                      onLongPressCancel: () {
                        if (!_longPressRangeActive) {
                          return;
                        }
                        _longPressRangeActive = false;
                        _clearRangeSelection();
                      },
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
                                  showEventTimes: !compact,
                                  hideSensitiveEvents:
                                      widget.hideSensitiveEvents,
                                  compact: compact,
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
    final weekCount = days.length ~/ 7;
    final row = (position.dy / (constraints.maxHeight / weekCount))
        .floor()
        .clamp(0, weekCount - 1);
    return days[row * 7 + col];
  }

  List<DateTime> _visibleDays(DateTime month, bool weekStartsOnMonday) {
    final first = DateTime(month.year, month.month);
    final leadingDays = weekStartsOnMonday
        ? first.weekday - 1
        : first.weekday % 7;
    final start = first.subtract(Duration(days: leadingDays));
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final requiredWeeks = ((leadingDays + daysInMonth) / 7).ceil();
    final weekCount = math.max(5, requiredWeeks);
    return List.generate(
      weekCount * 7,
      (index) => start.add(Duration(days: index)),
    );
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

  bool _isDesktopRangePointer(PointerDeviceKind kind) {
    return kind == PointerDeviceKind.mouse ||
        kind == PointerDeviceKind.trackpad;
  }

  bool _hasPrimaryButton(int buttons) {
    return (buttons & kPrimaryMouseButton) != 0;
  }

  int _maxFlagsForDensity(CalendarDensity density, {required double width}) {
    final standardTarget = switch (width) {
      <= 390 => 4,
      <= 430 => 5,
      <= 520 => 6,
      <= 720 => 7,
      <= 880 => 8,
      <= 1120 => 9,
      <= 1360 => 10,
      _ => 12,
    };
    return switch (density) {
      CalendarDensity.relaxed => math.max(3, standardTarget - 1),
      CalendarDensity.standard => standardTarget,
      CalendarDensity.dense => standardTarget + 1,
    };
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
    required this.showEventTimes,
    required this.hideSensitiveEvents,
    required this.compact,
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
  final bool showEventTimes;
  final bool hideSensitiveEvents;
  final bool compact;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final weekStart = weekDays.first;
    final weekEnd = weekStart.add(const Duration(days: 7));
    final segments = _layoutSegments(weekStart, weekEnd);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 7;
        var metrics = _MonthFlagMetrics.forLayout(
          compact: compact,
          rowHeight: constraints.maxHeight,
          maxFlags: maxFlags,
          reserveOverflow: false,
        );
        final flagInset = compact ? 1.0 : 5.0;
        final overflowInset = compact ? 2.0 : 6.0;
        var visibleLanes = metrics.visibleLanes;
        var overflowCounts = _overflowCounts(segments, visibleLanes);
        final hasOverflow = overflowCounts.any((count) => count > 0);
        if (hasOverflow) {
          metrics = _MonthFlagMetrics.forLayout(
            compact: compact,
            rowHeight: constraints.maxHeight,
            maxFlags: maxFlags,
            reserveOverflow: true,
          );
          visibleLanes = metrics.visibleLanes;
          overflowCounts = _overflowCounts(segments, visibleLanes);
        }
        final visibleSegments = segments
            .where((segment) => segment.lane < visibleLanes)
            .toList();
        final overflowTop = math.min(
          metrics.top +
              visibleLanes * (metrics.height + metrics.gap) +
              metrics.overflowGap,
          math.max(0.0, constraints.maxHeight - metrics.overflowHeight - 2),
        );
        final rangeSegment = _rangeHighlightSegment(weekStart);

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              if (rangeSegment != null)
                Positioned(
                  left: rangeSegment.startCol * cellWidth + 1.5,
                  top: 2,
                  width:
                      (rangeSegment.endCol - rangeSegment.startCol + 1) *
                          cellWidth -
                      3,
                  bottom: 2,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: ValueKey(
                        'selected-range-${weekStart.year}-${weekStart.month}-${weekStart.day}',
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffdbeafe),
                        borderRadius: BorderRadius.horizontal(
                          left: rangeSegment.roundLeading
                              ? const Radius.circular(8)
                              : Radius.zero,
                          right: rangeSegment.roundTrailing
                              ? const Radius.circular(8)
                              : Radius.zero,
                        ),
                        border: Border.all(color: const Color(0xff93c5fd)),
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  for (final day in weekDays)
                    Expanded(
                      child: _DayCellBackground(
                        day: day,
                        inMonth: day.month == month.month,
                        selected: _sameDay(day, selectedDate),
                        rangeHighlighted: _inSelectedRange(day),
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
                        left: segment.startCol * cellWidth + flagInset,
                        top:
                            metrics.top +
                            segment.lane * (metrics.height + metrics.gap),
                        width:
                            (segment.endCol - segment.startCol + 1) *
                                cellWidth -
                            flagInset * 2,
                        height: metrics.height,
                        child: _EventSpanFlag(
                          key: ValueKey(
                            'event-span-${segment.event.id}-${weekStart.year}-${weekStart.month}-${weekStart.day}',
                          ),
                          event: segment.event,
                          segmentStart: weekStart.add(
                            Duration(days: segment.startCol),
                          ),
                          showTime: showEventTimes,
                          hideSensitive: hideSensitiveEvents,
                          compact: compact,
                          dense: metrics.denseText,
                        ),
                      ),
                    for (var index = 0; index < overflowCounts.length; index++)
                      if (overflowCounts[index] > 0)
                        Positioned(
                          left: index * cellWidth + overflowInset,
                          top: overflowTop,
                          width: cellWidth - overflowInset * 2,
                          height: metrics.overflowHeight,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.84),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 2 : 4,
                                ),
                                child: Text(
                                  '+${overflowCounts[index]}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textScaler: TextScaler.noScaling,
                                  style: TextStyle(
                                    fontSize: compact ? 9 : 10,
                                    height: 1.0,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xff64748b),
                                  ),
                                ),
                              ),
                            ),
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

  _RangeHighlightSegment? _rangeHighlightSegment(DateTime weekStart) {
    final start = selectedRangeStart;
    final end = selectedRangeEnd;
    if (start == null || end == null) {
      return null;
    }

    final normalizedStart = _dayStart(start.isAfter(end) ? end : start);
    final normalizedEnd = _dayStart(start.isAfter(end) ? start : end);
    final weekLast = weekStart.add(const Duration(days: 6));
    if (normalizedEnd.isBefore(weekStart) ||
        normalizedStart.isAfter(weekLast)) {
      return null;
    }

    final segmentStart = normalizedStart.isAfter(weekStart)
        ? normalizedStart
        : weekStart;
    final segmentEnd = normalizedEnd.isBefore(weekLast)
        ? normalizedEnd
        : weekLast;
    return _RangeHighlightSegment(
      startCol: segmentStart.difference(weekStart).inDays,
      endCol: segmentEnd.difference(weekStart).inDays,
      roundLeading: _sameDay(segmentStart, normalizedStart),
      roundTrailing: _sameDay(segmentEnd, normalizedEnd),
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
    required this.rangeHighlighted,
    required this.today,
    required this.holiday,
    required this.showLunarDate,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool rangeHighlighted;
  final bool today;
  final bool holiday;
  final bool showLunarDate;
  final VoidCallback onTap;

  static const _lunarCalendar = KoreanLunarCalendar();

  @override
  Widget build(BuildContext context) {
    final fill = rangeHighlighted
        ? Colors.transparent
        : selected
        ? const Color(0xffedf4ff)
        : holiday && inMonth
        ? const Color(0xfffff4f4)
        : Colors.transparent;
    final lunar = showLunarDate ? _lunarCalendar.fromSolar(day) : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        key: ValueKey('day-cell-${day.year}-${day.month}-${day.day}'),
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(8),
          border: selected && !rangeHighlighted
              ? Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.30),
                )
              : Border.all(color: Colors.transparent),
        ),
        alignment: Alignment.topLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _DayNumber(
              key: ValueKey('day-number-${day.year}-${day.month}-${day.day}'),
              day: day,
              inMonth: inMonth,
              today: today,
              holiday: holiday,
            ),
            if (lunar != null) ...[
              const SizedBox(width: 3),
              Flexible(
                child: SizedBox(
                  height: 21,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        lunar.shortLabel,
                        maxLines: 1,
                        softWrap: false,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: 8.5,
                          height: 1.0,
                          color: inMonth
                              ? const Color(0xff9aa3af)
                              : const Color(0xffc7ccd4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayNumber extends StatelessWidget {
  const _DayNumber({
    super.key,
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

    final content = today
        ? Container(
            width: 21,
            height: 21,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xff2563eb),
            ),
            child: child,
          )
        : SizedBox(
            width: 21,
            height: 21,
            child: Align(alignment: Alignment.center, child: child),
          );

    return SizedBox(width: 21, height: 21, child: content);
  }
}

class _EventSpanFlag extends StatelessWidget {
  const _EventSpanFlag({
    super.key,
    required this.event,
    required this.segmentStart,
    required this.showTime,
    required this.hideSensitive,
    required this.compact,
    required this.dense,
  });

  final CalendarEvent event;
  final DateTime segmentStart;
  final bool showTime;
  final bool hideSensitive;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = Color(event.colorValue);
    final formatter = DateFormat('HH:mm');
    final showStartTime =
        showTime &&
        !event.allDay &&
        event.startAt.year == segmentStart.year &&
        event.startAt.month == segmentStart.month &&
        event.startAt.day == segmentStart.day;
    final prefix = event.showDday && !compact ? '${_formatDday(event)}  ' : '';
    final suffix = showStartTime ? '  ${formatter.format(event.startAt)}' : '';
    final title = hideSensitive && event.sensitive ? '비공개 일정' : event.title;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: event.holiday
            ? color.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: dense
              ? 2
              : compact
              ? 3
              : 7,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '$prefix$title$suffix',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: dense
                  ? 10
                  : compact
                  ? 10.5
                  : 11,
              height: dense ? 1.0 : null,
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

class _MonthFlagMetrics {
  const _MonthFlagMetrics({
    required this.top,
    required this.height,
    required this.gap,
    required this.visibleLanes,
    required this.denseText,
    required this.overflowHeight,
    required this.overflowGap,
  });

  final double top;
  final double height;
  final double gap;
  final int visibleLanes;
  final bool denseText;
  final double overflowHeight;
  final double overflowGap;

  static _MonthFlagMetrics forLayout({
    required bool compact,
    required double rowHeight,
    required int maxFlags,
    required bool reserveOverflow,
  }) {
    var top = compact ? 22.0 : 27.0;
    var bottomReserve = compact ? 3.0 : 10.0;
    final overflowHeight = compact ? 10.0 : 12.0;
    final overflowGap = compact ? 1.0 : 2.0;
    final regularHeight = compact ? 13.0 : 19.0;
    final regularGap = compact ? 1.0 : 2.0;
    final tightHeight = compact ? 10.5 : 13.0;
    final tightGap = compact ? 1.0 : 2.0;
    final overflowReserve = reserveOverflow ? overflowHeight + overflowGap : 0;
    final minimumVisibleLanes = math.min(4, maxFlags);
    double usableHeight() =>
        math.max(0.0, rowHeight - top - bottomReserve - overflowReserve);

    var height = regularHeight;
    var gap = regularGap;
    var visibleLanes = _lanesThatFit(
      usableHeight: usableHeight(),
      height: height,
      gap: gap,
      maxFlags: maxFlags,
    );
    var denseText = false;

    if (visibleLanes < minimumVisibleLanes) {
      // On shorter desktop windows, keep four event rows readable instead of
      // leaving a large empty cell with a single visible event.
      if (!compact) {
        top = 18.0;
        bottomReserve = 1.0;
      }
      height = tightHeight;
      gap = tightGap;
      visibleLanes = _lanesThatFit(
        usableHeight: usableHeight(),
        height: height,
        gap: gap,
        maxFlags: maxFlags,
      );
      denseText = true;
    }

    return _MonthFlagMetrics(
      top: top,
      height: height,
      gap: gap,
      visibleLanes: math.max(1, visibleLanes),
      denseText: denseText,
      overflowHeight: overflowHeight,
      overflowGap: overflowGap,
    );
  }

  static int _lanesThatFit({
    required double usableHeight,
    required double height,
    required double gap,
    required int maxFlags,
  }) {
    if (usableHeight <= 0) {
      return 1;
    }
    final lanes = ((usableHeight + gap) / (height + gap)).floor();
    return math.max(1, math.min(maxFlags, lanes));
  }
}

class _RangeHighlightSegment {
  const _RangeHighlightSegment({
    required this.startCol,
    required this.endCol,
    required this.roundLeading,
    required this.roundTrailing,
  });

  final int startCol;
  final int endCol;
  final bool roundLeading;
  final bool roundTrailing;
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
