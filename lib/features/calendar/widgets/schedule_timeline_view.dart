import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../events/domain/calendar_event.dart';

class ScheduleTimelineView extends StatefulWidget {
  const ScheduleTimelineView({
    super.key,
    required this.days,
    required this.events,
    required this.selectedDate,
    required this.use24HourTime,
    required this.showAllDayEvents,
    required this.onShowAllDayEventsChanged,
    required this.onDateSelected,
  });

  final List<DateTime> days;
  final List<CalendarEvent> events;
  final DateTime selectedDate;
  final bool use24HourTime;
  final bool showAllDayEvents;
  final ValueChanged<bool> onShowAllDayEventsChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<ScheduleTimelineView> createState() => _ScheduleTimelineViewState();
}

class _ScheduleTimelineViewState extends State<ScheduleTimelineView> {
  static const _hourHeight = 64.0;
  static const _initialHour = 7;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: _initialHour * _hourHeight,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allDayEvents = widget.events.where((event) => event.allDay).toList();
    final showAllDayArea = widget.showAllDayEvents && allDayEvents.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      key: const ValueKey('schedule-timeline'),
      children: [
        _ScheduleDayHeader(
          days: widget.days,
          selectedDate: widget.selectedDate,
          onDateSelected: widget.onDateSelected,
        ),
        if (showAllDayArea)
          _AllDayEventStrip(
            days: widget.days,
            events: allDayEvents,
            onDateSelected: widget.onDateSelected,
          ),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(
          child: Stack(
            children: [
              Scrollbar(
                controller: _scrollController,
                child: SingleChildScrollView(
                  key: const ValueKey('schedule-time-scroll'),
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: _ScheduleTimeGrid(
                    days: widget.days,
                    events: widget.events
                        .where((event) => !event.allDay)
                        .toList(),
                    use24HourTime: widget.use24HourTime,
                    onDateSelected: widget.onDateSelected,
                  ),
                ),
              ),
              PositionedDirectional(
                end: 12,
                bottom: 12,
                child: Material(
                  color: widget.showAllDayEvents
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  elevation: 2,
                  shape: const CircleBorder(),
                  child: IconButton(
                    key: const ValueKey('schedule-all-day-toggle'),
                    tooltip: context.tr(
                      widget.showAllDayEvents ? '종일 일정 숨기기' : '종일 일정 표시',
                    ),
                    onPressed: () => widget.onShowAllDayEventsChanged(
                      !widget.showAllDayEvents,
                    ),
                    icon: Icon(
                      widget.showAllDayEvents
                          ? Icons.event_available_outlined
                          : Icons.event_busy_outlined,
                      color: widget.showAllDayEvents
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleDayHeader extends StatelessWidget {
  const _ScheduleDayHeader({
    required this.days,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final List<DateTime> days;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;
    final compact = days.length > 1;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          SizedBox(width: compact ? 42 : 54),
          for (final day in days)
            Expanded(
              child: InkWell(
                onTap: () => onDateSelected(day),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 3 : 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _isSameDay(day, selectedDate)
                          ? scheme.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      compact
                          ? '${DateFormat.E(locale).format(day)}\n${day.day}'
                          : DateFormat.MMMEd(locale).format(day),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: _isSameDay(day, selectedDate)
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                        fontWeight: _isSameDay(day, DateTime.now())
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AllDayEventStrip extends StatelessWidget {
  const _AllDayEventStrip({
    required this.days,
    required this.events,
    required this.onDateSelected,
  });

  final List<DateTime> days;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final compact = days.length > 1;
    return ConstrainedBox(
      key: const ValueKey('schedule-all-day-area'),
      constraints: const BoxConstraints(minHeight: 34, maxHeight: 76),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: compact ? 42 : 54,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: 7, end: 5),
              child: Text(
                context.tr('종일'),
                textAlign: TextAlign.end,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          for (final day in days)
            Expanded(
              child: InkWell(
                onTap: () => onDateSelected(day),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 3, 2, 4),
                  child: Column(
                    children: [
                      for (final event in _eventsForDate(events, day).take(2))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: _AllDayEventChip(event: event),
                        ),
                      if (_eventsForDate(events, day).length > 2)
                        Text(
                          '+${_eventsForDate(events, day).length - 2}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AllDayEventChip extends StatelessWidget {
  const _AllDayEventChip({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final color = Color(event.colorValue);
    return Container(
      height: 24,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(5),
        border: BorderDirectional(start: BorderSide(color: color, width: 3)),
      ),
      child: Text(
        context.l10n.eventTitle(event.title, holiday: event.holiday),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _ScheduleTimeGrid extends StatelessWidget {
  const _ScheduleTimeGrid({
    required this.days,
    required this.events,
    required this.use24HourTime,
    required this.onDateSelected,
  });

  static const _hourHeight = 64.0;

  final List<DateTime> days;
  final List<CalendarEvent> events;
  final bool use24HourTime;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = days.length > 1;
    final gutterWidth = compact ? 42.0 : 54.0;
    final layouts = <int, List<_TimelineSegmentLayout>>{
      for (var index = 0; index < days.length; index++)
        index: _layoutSegments(_segmentsForDate(events, days[index])),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = math.max(1.0, constraints.maxWidth - gutterWidth);
        final dayWidth = contentWidth / days.length;
        return SizedBox(
          height: 24 * _hourHeight,
          width: constraints.maxWidth,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (var hour = 0; hour <= 24; hour++) ...[
                Positioned(
                  top: hour * _hourHeight,
                  left: gutterWidth,
                  right: 0,
                  child: Divider(height: 1, color: scheme.outlineVariant),
                ),
                if (hour < 24)
                  Positioned(
                    top: hour * _hourHeight + 3,
                    left: 0,
                    width: gutterWidth - 5,
                    child: Text(
                      _hourLabel(context, hour),
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
              for (var dayIndex = 0; dayIndex <= days.length; dayIndex++)
                Positioned(
                  left: gutterWidth + dayWidth * dayIndex,
                  top: 0,
                  bottom: 0,
                  child: VerticalDivider(
                    width: 1,
                    color: scheme.outlineVariant,
                  ),
                ),
              for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
                Positioned(
                  left: gutterWidth + dayWidth * dayIndex,
                  top: 0,
                  width: dayWidth,
                  height: 24 * _hourHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => onDateSelected(days[dayIndex]),
                  ),
                ),
              for (final entry in layouts.entries)
                for (final layout in entry.value)
                  _buildEventBlock(
                    context,
                    layout,
                    gutterWidth + dayWidth * entry.key,
                    dayWidth,
                    days[entry.key],
                  ),
              if (days.any((day) => _isSameDay(day, DateTime.now())))
                _buildCurrentTimeIndicator(
                  context,
                  days,
                  gutterWidth,
                  dayWidth,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventBlock(
    BuildContext context,
    _TimelineSegmentLayout layout,
    double dayLeft,
    double dayWidth,
    DateTime day,
  ) {
    const gap = 2.0;
    final laneWidth = (dayWidth - gap * 2) / layout.laneCount;
    final left = dayLeft + gap + laneWidth * layout.lane;
    final top = layout.startMinute / 60 * _hourHeight + 1;
    final height = math.max(
      24.0,
      (layout.endMinute - layout.startMinute) / 60 * _hourHeight - 2,
    );
    final color = Color(layout.event.colorValue);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final start = layout.event.startAt;
    final time = use24HourTime
        ? DateFormat.Hm(locale).format(start)
        : DateFormat.jm(locale).format(start);
    return Positioned(
      key: ValueKey(
        'schedule-event-${layout.event.id}-${day.toIso8601String()}',
      ),
      left: left,
      top: top,
      width: math.max(1, laneWidth - gap),
      height: height,
      child: Material(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onDateSelected(day),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(5, 3, 3, 2),
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: color, width: 3),
              ),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: context.l10n.eventTitle(
                      layout.event.title,
                      holiday: layout.event.holiday,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: '\n$time'),
                ],
              ),
              maxLines: height >= 42 ? 3 : 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: color, height: 1.15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(
    BuildContext context,
    List<DateTime> days,
    double gutterWidth,
    double dayWidth,
  ) {
    final now = DateTime.now();
    final dayIndex = days.indexWhere((day) => _isSameDay(day, now));
    final top = (now.hour * 60 + now.minute) / 60 * _hourHeight;
    return Positioned(
      left: gutterWidth + dayWidth * dayIndex,
      top: top,
      width: dayWidth,
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1.5,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  String _hourLabel(BuildContext context, int hour) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final value = DateTime(2020, 1, 1, hour);
    return use24HourTime
        ? DateFormat.Hm(locale).format(value)
        : DateFormat.jm(locale).format(value);
  }
}

class _TimelineSegment {
  const _TimelineSegment({
    required this.event,
    required this.startMinute,
    required this.endMinute,
  });

  final CalendarEvent event;
  final int startMinute;
  final int endMinute;
}

class _TimelineSegmentLayout {
  const _TimelineSegmentLayout({
    required this.event,
    required this.startMinute,
    required this.endMinute,
    required this.lane,
    required this.laneCount,
  });

  final CalendarEvent event;
  final int startMinute;
  final int endMinute;
  final int lane;
  final int laneCount;
}

List<_TimelineSegment> _segmentsForDate(
  List<CalendarEvent> events,
  DateTime date,
) {
  final dayStart = DateTime(date.year, date.month, date.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final segments = <_TimelineSegment>[];
  for (final event in events) {
    if (event.allDay ||
        !event.startAt.isBefore(dayEnd) ||
        !event.endAt.isAfter(dayStart)) {
      continue;
    }
    final start = event.startAt.isAfter(dayStart) ? event.startAt : dayStart;
    final end = event.endAt.isBefore(dayEnd) ? event.endAt : dayEnd;
    final startMinute = start.difference(dayStart).inMinutes.clamp(0, 1439);
    final endMinute = end.difference(dayStart).inMinutes.clamp(1, 1440);
    segments.add(
      _TimelineSegment(
        event: event,
        startMinute: startMinute,
        endMinute: math.max(startMinute + 1, endMinute),
      ),
    );
  }
  segments.sort((a, b) {
    final byStart = a.startMinute.compareTo(b.startMinute);
    if (byStart != 0) return byStart;
    return b.endMinute.compareTo(a.endMinute);
  });
  return segments;
}

List<_TimelineSegmentLayout> _layoutSegments(List<_TimelineSegment> segments) {
  final layouts = <_TimelineSegmentLayout>[];
  var offset = 0;
  while (offset < segments.length) {
    var groupEnd = segments[offset].endMinute;
    var end = offset + 1;
    while (end < segments.length && segments[end].startMinute < groupEnd) {
      groupEnd = math.max(groupEnd, segments[end].endMinute);
      end++;
    }
    final laneEnds = <int>[];
    final assigned = <({_TimelineSegment segment, int lane})>[];
    for (final segment in segments.sublist(offset, end)) {
      var lane = laneEnds.indexWhere(
        (laneEnd) => laneEnd <= segment.startMinute,
      );
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(segment.endMinute);
      } else {
        laneEnds[lane] = segment.endMinute;
      }
      assigned.add((segment: segment, lane: lane));
    }
    for (final item in assigned) {
      layouts.add(
        _TimelineSegmentLayout(
          event: item.segment.event,
          startMinute: item.segment.startMinute,
          endMinute: item.segment.endMinute,
          lane: item.lane,
          laneCount: laneEnds.length,
        ),
      );
    }
    offset = end;
  }
  return layouts;
}

List<CalendarEvent> _eventsForDate(List<CalendarEvent> events, DateTime date) {
  final start = DateTime(date.year, date.month, date.day);
  final end = start.add(const Duration(days: 1));
  return events
      .where(
        (event) => event.startAt.isBefore(end) && event.endAt.isAfter(start),
      )
      .toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
}

bool _isSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
