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
    this.showAdjacentMonthDates = true,
    this.continuous = false,
    this.showWeekdayHeader = true,
    this.onRangeHitTestBoxChanged,
    this.externalRangeStart,
    this.externalRangeEnd,
    this.enableRangeGestures = true,
    required this.onDateSelected,
    this.onDateRangeSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final List<CalendarEvent> events;
  final bool weekStartsOnMonday;
  final bool showLunarDates;
  final bool showAdjacentMonthDates;
  final bool continuous;
  final bool showWeekdayHeader;
  final ValueChanged<RenderBox?>? onRangeHitTestBoxChanged;
  final DateTime? externalRangeStart;
  final DateTime? externalRangeEnd;
  final bool enableRangeGestures;
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
  Offset? _mouseDownPosition;
  late List<DateTime> _days;
  late List<List<DateTime>> _weeks;
  late Set<DateTime> _holidayDays;
  RenderBox? _reportedRangeHitTestBox;

  @override
  void initState() {
    super.initState();
    _rebuildCalendarCache();
  }

  @override
  void dispose() {
    widget.onRangeHitTestBoxChanged?.call(null);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CalendarMonthGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month != widget.month ||
        oldWidget.weekStartsOnMonday != widget.weekStartsOnMonday) {
      _rebuildDayCache();
    }
    if (!identical(oldWidget.events, widget.events)) {
      _holidayDays = _holidayDaysFor(widget.events);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    final maxFlags = _standardMaxFlagsForWidth(width);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(4, 0, 4, 8)
          : const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
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
              if (widget.showWeekdayHeader)
                CalendarWeekdayHeader(
                  weekStartsOnMonday: widget.weekStartsOnMonday,
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _reportRangeHitTestBox(context);
                    return Listener(
                      onPointerDown: (event) {
                        if (!widget.enableRangeGestures) {
                          return;
                        }
                        if (!_isDesktopRangePointer(event.kind) ||
                            !_hasPrimaryButton(event.buttons)) {
                          return;
                        }
                        _mouseRangeActive = false;
                        _longPressRangeActive = false;
                        _mouseDownPosition = event.localPosition;
                      },
                      onPointerMove: (event) {
                        if (!widget.enableRangeGestures) {
                          return;
                        }
                        if (!_isDesktopRangePointer(event.kind)) {
                          return;
                        }
                        final downPosition = _mouseDownPosition;
                        if (downPosition == null) {
                          return;
                        }
                        if (!_mouseRangeActive) {
                          final downDay = _dayAtPosition(
                            downPosition,
                            _days,
                            constraints,
                          );
                          final currentDay = _dayAtPosition(
                            event.localPosition,
                            _days,
                            constraints,
                          );
                          if (downDay == null ||
                              currentDay == null ||
                              _sameDay(downDay, currentDay)) {
                            return;
                          }
                          _mouseRangeActive = true;
                          _startRangeSelection(
                            downPosition,
                            _days,
                            constraints,
                          );
                        }
                        _updateRangeSelection(
                          event.localPosition,
                          _days,
                          constraints,
                        );
                      },
                      onPointerUp: (event) {
                        if (!widget.enableRangeGestures) {
                          return;
                        }
                        if (!_isDesktopRangePointer(event.kind)) {
                          return;
                        }
                        _mouseDownPosition = null;
                        if (!_mouseRangeActive) {
                          return;
                        }
                        _mouseRangeActive = false;
                        _finishRangeSelection();
                      },
                      onPointerCancel: (event) {
                        if (!widget.enableRangeGestures) {
                          return;
                        }
                        if (!_isDesktopRangePointer(event.kind)) {
                          return;
                        }
                        _mouseDownPosition = null;
                        if (!_mouseRangeActive && !_longPressRangeActive) {
                          return;
                        }
                        _mouseRangeActive = false;
                        _longPressRangeActive = false;
                        _clearRangeSelection();
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        // Desktop range selection is handled by the Listener
                        // above. Keeping this recognizer touch-only prevents a
                        // mouse click from entering the long-press gesture arena
                        // with the day cell's InkWell.
                        supportedDevices: const {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.stylus,
                          PointerDeviceKind.invertedStylus,
                        },
                        onLongPressStart: widget.enableRangeGestures
                            ? (details) {
                                if (_mouseRangeActive) {
                                  return;
                                }
                                _longPressRangeActive = true;
                                _startRangeSelection(
                                  details.localPosition,
                                  _days,
                                  constraints,
                                );
                              }
                            : null,
                        onLongPressMoveUpdate: widget.enableRangeGestures
                            ? (details) {
                                if (!_longPressRangeActive) {
                                  return;
                                }
                                _updateRangeSelection(
                                  details.localPosition,
                                  _days,
                                  constraints,
                                );
                              }
                            : null,
                        onLongPressEnd: widget.enableRangeGestures
                            ? (_) {
                                if (!_longPressRangeActive) {
                                  return;
                                }
                                _longPressRangeActive = false;
                                _finishRangeSelection();
                              }
                            : null,
                        onLongPressCancel: widget.enableRangeGestures
                            ? () {
                                if (!_longPressRangeActive) {
                                  return;
                                }
                                _longPressRangeActive = false;
                                _clearRangeSelection();
                              }
                            : null,
                        child: Column(
                          children: [
                            for (final week in _weeks)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: _WeekRow(
                                    key: ValueKey(
                                      'week-row-${week.first.year}-${week.first.month}-${week.first.day}',
                                    ),
                                    month: widget.month,
                                    selectedDate: widget.selectedDate,
                                    selectedRangeStart:
                                        widget.externalRangeStart ??
                                        _rangeStart,
                                    selectedRangeEnd:
                                        widget.externalRangeEnd ?? _rangeEnd,
                                    weekDays: week,
                                    events: widget.events,
                                    maxFlags: maxFlags,
                                    holidayDays: _holidayDays,
                                    showLunarDates: widget.showLunarDates,
                                    showAdjacentMonthDates:
                                        widget.showAdjacentMonthDates,
                                    showEventTimes: !compact,
                                    compact: compact,
                                    onDateSelected: widget.onDateSelected,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _rebuildCalendarCache() {
    _rebuildDayCache();
    _holidayDays = _holidayDaysFor(widget.events);
  }

  void _reportRangeHitTestBox(BuildContext context) {
    if (widget.onRangeHitTestBoxChanged == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final renderObject = context.findRenderObject();
      final box = renderObject is RenderBox && renderObject.hasSize
          ? renderObject
          : null;
      if (identical(_reportedRangeHitTestBox, box)) {
        return;
      }
      _reportedRangeHitTestBox = box;
      widget.onRangeHitTestBoxChanged?.call(box);
    });
  }

  void _rebuildDayCache() {
    _days = _visibleDays(widget.month, widget.weekStartsOnMonday);
    _weeks = List.generate(
      _days.length ~/ 7,
      (weekIndex) => _days.sublist(weekIndex * 7, weekIndex * 7 + 7),
      growable: false,
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
    final weekCount = widget.continuous
        ? requiredWeeks
        : math.max(5, requiredWeeks);
    return List.generate(
      weekCount * 7,
      (index) => start.add(Duration(days: index)),
    );
  }

  Set<DateTime> _holidayDaysFor(List<CalendarEvent> events) {
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

  int _standardMaxFlagsForWidth(double width) {
    return switch (width) {
      <= 390 => 4,
      <= 430 => 5,
      <= 520 => 6,
      <= 720 => 7,
      <= 880 => 8,
      <= 1120 => 9,
      <= 1360 => 10,
      _ => 12,
    };
  }
}

class CalendarWeekdayHeader extends StatelessWidget {
  const CalendarWeekdayHeader({super.key, required this.weekStartsOnMonday});

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
                      color: _weekdayColor(
                        label,
                        Theme.of(context).colorScheme,
                      ),
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

  Color _weekdayColor(String label, ColorScheme colorScheme) {
    if (label == '일') {
      return const Color(0xffef4444);
    }
    if (label == '토') {
      return const Color(0xff2563eb);
    }
    return colorScheme.onSurfaceVariant;
  }
}

class _WeekRow extends StatefulWidget {
  const _WeekRow({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.selectedRangeStart,
    required this.selectedRangeEnd,
    required this.weekDays,
    required this.events,
    required this.maxFlags,
    required this.holidayDays,
    required this.showLunarDates,
    required this.showAdjacentMonthDates,
    required this.showEventTimes,
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
  final bool showAdjacentMonthDates;
  final bool showEventTimes;
  final bool compact;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<_WeekRow> createState() => _WeekRowState();
}

class _WeekRowState extends State<_WeekRow> {
  late List<_EventSegment> _segments;

  @override
  void initState() {
    super.initState();
    _rebuildSegments();
  }

  @override
  void didUpdateWidget(covariant _WeekRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month != widget.month ||
        oldWidget.showAdjacentMonthDates != widget.showAdjacentMonthDates ||
        !_sameEventInstances(oldWidget.events, widget.events) ||
        !_sameDays(oldWidget.weekDays, widget.weekDays)) {
      _rebuildSegments();
    }
  }

  void _rebuildSegments() {
    final weekStart = widget.weekDays.first;
    _segments = _layoutSegments(
      weekStart,
      weekStart.add(const Duration(days: 7)),
    );
  }

  bool _sameEventInstances(
    List<CalendarEvent> first,
    List<CalendarEvent> second,
  ) {
    if (identical(first, second)) {
      return true;
    }
    if (first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index++) {
      if (!identical(first[index], second[index])) {
        return false;
      }
    }
    return true;
  }

  bool _sameDays(List<DateTime> first, List<DateTime> second) {
    if (identical(first, second)) {
      return true;
    }
    if (first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final weekStart = widget.weekDays.first;
    final segments = _segments;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 7;
        var metrics = _MonthFlagMetrics.forLayout(
          compact: widget.compact,
          rowHeight: constraints.maxHeight,
          maxFlags: widget.maxFlags,
          reserveOverflow: false,
        );
        final flagInset = widget.compact ? 1.0 : 5.0;
        final overflowInset = widget.compact ? 2.0 : 6.0;
        var visibleLanes = metrics.visibleLanes;
        var overflowCounts = _overflowCounts(segments, visibleLanes);
        final hasOverflow = overflowCounts.any((count) => count > 0);
        if (hasOverflow) {
          metrics = _MonthFlagMetrics.forLayout(
            compact: widget.compact,
            rowHeight: constraints.maxHeight,
            maxFlags: widget.maxFlags,
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
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.55,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  for (final day in widget.weekDays)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final showContent =
                              widget.showAdjacentMonthDates ||
                              (day.year == widget.month.year &&
                                  day.month == widget.month.month);
                          return _DayCellBackground(
                            day: day,
                            inMonth:
                                day.year == widget.month.year &&
                                day.month == widget.month.month,
                            selected:
                                showContent &&
                                _sameDay(day, widget.selectedDate),
                            rangeHighlighted:
                                showContent && _inSelectedRange(day),
                            today: _sameDay(day, DateTime.now()),
                            holiday: widget.holidayDays.contains(
                              _dayStart(day),
                            ),
                            showLunarDate: widget.showLunarDates,
                            showContent: showContent,
                            onTap: showContent
                                ? () => widget.onDateSelected(day)
                                : null,
                          );
                        },
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
                          showTime: widget.showEventTimes,
                          compact: widget.compact,
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
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: widget.compact ? 2 : 4,
                                ),
                                child: Text(
                                  '+${overflowCounts[index]}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: widget.compact ? 9 : 10,
                                    height: 1.0,
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.onSurfaceVariant,
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
    final start = widget.selectedRangeStart;
    final end = widget.selectedRangeEnd;
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

    var segmentStart = normalizedStart.isAfter(weekStart)
        ? normalizedStart
        : weekStart;
    var segmentEnd = normalizedEnd.isBefore(weekLast)
        ? normalizedEnd
        : weekLast;
    if (!widget.showAdjacentMonthDates) {
      final monthStart = DateTime(widget.month.year, widget.month.month);
      final monthEnd = DateTime(widget.month.year, widget.month.month + 1, 0);
      if (segmentStart.isBefore(monthStart)) {
        segmentStart = monthStart;
      }
      if (segmentEnd.isAfter(monthEnd)) {
        segmentEnd = monthEnd;
      }
      if (segmentEnd.isBefore(segmentStart)) {
        return null;
      }
    }
    return _RangeHighlightSegment(
      startCol: segmentStart.difference(weekStart).inDays,
      endCol: segmentEnd.difference(weekStart).inDays,
    );
  }

  List<_EventSegment> _layoutSegments(DateTime weekStart, DateTime weekEnd) {
    final rawSegments =
        widget.events
            .where((event) => event.overlaps(weekStart, weekEnd))
            .map((event) => _EventSegment.fromEvent(event, weekStart))
            .where((segment) => segment != null)
            .cast<_EventSegment>()
            .map(_clipToVisibleMonth)
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

  _EventSegment? _clipToVisibleMonth(_EventSegment segment) {
    if (widget.showAdjacentMonthDates) {
      return segment;
    }
    final visibleColumns = <int>[
      for (var index = 0; index < widget.weekDays.length; index++)
        if (widget.weekDays[index].year == widget.month.year &&
            widget.weekDays[index].month == widget.month.month)
          index,
    ];
    if (visibleColumns.isEmpty) {
      return null;
    }
    final startCol = math.max(segment.startCol, visibleColumns.first);
    final endCol = math.min(segment.endCol, visibleColumns.last);
    if (endCol < startCol) {
      return null;
    }
    return segment.copyWith(startCol: startCol, endCol: endCol);
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
    final start = widget.selectedRangeStart;
    final end = widget.selectedRangeEnd;
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
    required this.showContent,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool rangeHighlighted;
  final bool today;
  final bool holiday;
  final bool showLunarDate;
  final bool showContent;
  final VoidCallback? onTap;

  static const _lunarCalendar = KoreanLunarCalendar();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fill = rangeHighlighted
        ? Colors.transparent
        : selected
        ? colorScheme.primaryContainer.withValues(alpha: 0.45)
        : holiday && inMonth
        ? colorScheme.errorContainer.withValues(alpha: 0.28)
        : Colors.transparent;
    final lunar = showContent && showLunarDate
        ? _lunarCalendar.fromSolar(day)
        : null;

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
        child: !showContent
            ? const SizedBox.shrink()
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _DayNumber(
                    key: ValueKey(
                      'day-number-${day.year}-${day.month}-${day.day}',
                    ),
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
                              style: TextStyle(
                                fontSize: 8.5,
                                height: 1.0,
                                color: inMonth
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.outline,
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
    final colorScheme = Theme.of(context).colorScheme;
    final color = !inMonth
        ? colorScheme.outline
        : today
        ? Colors.white
        : holiday || day.weekday == DateTime.sunday
        ? const Color(0xffef4444)
        : day.weekday == DateTime.saturday
        ? const Color(0xff2563eb)
        : colorScheme.onSurface;

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
    required this.compact,
    required this.dense,
  });

  final CalendarEvent event;
  final DateTime segmentStart;
  final bool showTime;
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
    final title = event.title;

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
        child: Row(
          children: [
            Expanded(
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
          ],
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
    var top = 27.0;
    var bottomReserve = compact ? 3.0 : 10.0;
    final overflowHeight = compact ? 10.0 : 12.0;
    final overflowGap = compact ? 1.0 : 2.0;
    final regularHeight = compact ? 13.0 : 19.0;
    final regularGap = compact ? 1.0 : 2.0;
    const tightHeight = 12.0;
    const tightGap = 1.0;
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
      if (!compact) {
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
  const _RangeHighlightSegment({required this.startCol, required this.endCol});

  final int startCol;
  final int endCol;
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

  _EventSegment copyWith({int? startCol, int? endCol, int? lane}) {
    return _EventSegment(
      event: event,
      startCol: startCol ?? this.startCol,
      endCol: endCol ?? this.endCol,
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
