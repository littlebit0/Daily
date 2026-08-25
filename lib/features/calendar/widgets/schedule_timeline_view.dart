import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/calendar/calendar_event_movement.dart';
import '../../../core/calendar/calendar_event_ordering.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/event_completion_style.dart';
import '../../events/domain/calendar_event.dart';
import 'calendar_event_drag_layer.dart';

class ScheduleTimelineView extends StatefulWidget {
  const ScheduleTimelineView({
    super.key,
    required this.days,
    required this.events,
    required this.selectedDate,
    required this.use24HourTime,
    required this.showAllDayEvents,
    required this.holidayBackgroundEnabled,
    required this.holidayColorValue,
    this.centerEventTitles = false,
    this.eventSortPriority = CalendarEventSortPriority.time,
    this.categoryOrder = const <String>[],
    this.weekStartsOnMonday = false,
    this.onEventDropped,
    required this.onShowAllDayEventsChanged,
    required this.onDateSelected,
  });

  final List<DateTime> days;
  final List<CalendarEvent> events;
  final DateTime selectedDate;
  final bool use24HourTime;
  final bool showAllDayEvents;
  final bool holidayBackgroundEnabled;
  final int holidayColorValue;
  final bool centerEventTitles;
  final CalendarEventSortPriority eventSortPriority;
  final List<String> categoryOrder;
  final bool weekStartsOnMonday;
  final CalendarEventDropCallback? onEventDropped;
  final ValueChanged<bool> onShowAllDayEventsChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<ScheduleTimelineView> createState() => _ScheduleTimelineViewState();
}

class _ScheduleTimelineViewState extends State<ScheduleTimelineView> {
  static const _hourHeight = 64.0;
  static const _initialHour = 7;

  late final ScrollController _scrollController;
  CalendarEvent? _draggingEvent;

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
    final holidayEvents = widget.events
        .where((event) => event.holiday)
        .toList();
    final holidayDates = {
      for (final day in widget.days)
        if (holidayEvents.any((event) => _eventOccursOnDate(event, day)))
          DateTime(day.year, day.month, day.day),
    };

    final timeline = Column(
      key: const ValueKey('schedule-timeline'),
      children: [
        _ScheduleDayHeader(
          days: widget.days,
          selectedDate: widget.selectedDate,
          holidayDates: holidayDates,
          onEventDropped: widget.onEventDropped,
          onDateSelected: widget.onDateSelected,
        ),
        if (showAllDayArea)
          _AllDayEventStrip(
            days: widget.days,
            events: allDayEvents,
            centerEventTitles: widget.centerEventTitles,
            eventSortPriority: widget.eventSortPriority,
            categoryOrder: widget.categoryOrder,
            onEventDropped: widget.onEventDropped,
            onEventDragStateChanged: _setDraggingEvent,
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
                    centerEventTitles: widget.centerEventTitles,
                    eventSortPriority: widget.eventSortPriority,
                    categoryOrder: widget.categoryOrder,
                    onEventDropped: widget.onEventDropped,
                    onEventDragStateChanged: _setDraggingEvent,
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
    if (widget.days.length != 1 ||
        _draggingEvent == null ||
        widget.onEventDropped == null) {
      return timeline;
    }
    return Stack(
      children: [
        timeline,
        Positioned.fill(
          child: CalendarEventMonthDropOverlay(
            focusDate: widget.days.single,
            weekStartsOnMonday: widget.weekStartsOnMonday,
            onEventDropped: widget.onEventDropped!,
          ),
        ),
      ],
    );
  }

  void _setDraggingEvent(CalendarEvent? event) {
    if (mounted && _draggingEvent != event) {
      setState(() => _draggingEvent = event);
    }
  }
}

class _ScheduleDayHeader extends StatelessWidget {
  const _ScheduleDayHeader({
    required this.days,
    required this.selectedDate,
    required this.holidayDates,
    required this.onEventDropped,
    required this.onDateSelected,
  });

  final List<DateTime> days;
  final DateTime selectedDate;
  final Set<DateTime> holidayDates;
  final CalendarEventDropCallback? onEventDropped;
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
              child: CalendarEventDateDropTarget(
                date: day,
                onEventDropped: onEventDropped,
                child: InkWell(
                  onTap: () => onDateSelected(day),
                  child: Center(
                    child: Container(
                      key: ValueKey(
                        'schedule-day-background-${day.year}-${day.month}-${day.day}',
                      ),
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
                        key: ValueKey(
                          'schedule-day-header-${day.year}-${day.month}-${day.day}',
                        ),
                        compact
                            ? '${DateFormat.E(locale).format(day)}\n${day.day}'
                            : DateFormat.MMMEd(locale).format(day),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: _dayColor(day, scheme),
                              fontWeight: _isSameDay(day, DateTime.now())
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
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

  Color _dayColor(DateTime day, ColorScheme scheme) {
    if (_isSameDay(day, selectedDate)) {
      return scheme.onPrimaryContainer;
    }
    if (_isHoliday(day) || day.weekday == DateTime.sunday) {
      return const Color(0xffef4444);
    }
    if (day.weekday == DateTime.saturday) {
      return const Color(0xff2563eb);
    }
    return scheme.onSurface;
  }

  bool _isHoliday(DateTime day) {
    return holidayDates.contains(DateTime(day.year, day.month, day.day));
  }
}

class _AllDayEventStrip extends StatelessWidget {
  const _AllDayEventStrip({
    required this.days,
    required this.events,
    required this.centerEventTitles,
    required this.eventSortPriority,
    required this.categoryOrder,
    required this.onEventDropped,
    required this.onEventDragStateChanged,
    required this.onDateSelected,
  });

  final List<DateTime> days;
  final List<CalendarEvent> events;
  final bool centerEventTitles;
  final CalendarEventSortPriority eventSortPriority;
  final List<String> categoryOrder;
  final CalendarEventDropCallback? onEventDropped;
  final ValueChanged<CalendarEvent?> onEventDragStateChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final compact = days.length > 1;
    final eventComparator = calendarEventComparator(
      priority: eventSortPriority,
      categoryOrder: categoryOrder,
    );
    final eventsByDay = <DateTime, List<CalendarEvent>>{
      for (final day in days)
        DateTime(day.year, day.month, day.day): _eventsForDate(
          events,
          day,
          eventComparator,
        ),
    };
    final rowCount = eventsByDay.values.fold<int>(
      0,
      (current, events) => math.max(current, events.length),
    );
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    final chipHeight = 24.0 * textScale;
    const rowGap = 2.0;
    const verticalPadding = 7.0;
    const maximumVisibleRows = 4;
    final visibleRows = math.min(rowCount, maximumVisibleRows);
    final stripHeight = math.max(
      34.0,
      verticalPadding + visibleRows * chipHeight + (visibleRows - 1) * rowGap,
    );

    return SizedBox(
      key: const ValueKey('schedule-all-day-area'),
      height: stripHeight,
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
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('schedule-all-day-scroll'),
              primary: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final day in days)
                    Expanded(
                      child: CalendarEventDateDropTarget(
                        date: day,
                        onEventDropped: onEventDropped,
                        child: InkWell(
                          onTap: () => onDateSelected(day),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(2, 3, 2, 4),
                            child: Column(
                              children: [
                                for (final event
                                    in eventsByDay[DateTime(
                                      day.year,
                                      day.month,
                                      day.day,
                                    )]!)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: rowGap,
                                    ),
                                    child: CalendarEventDraggable(
                                      event: event,
                                      enabled: onEventDropped != null,
                                      onDragStateChanged: (dragging) =>
                                          onEventDragStateChanged(
                                            dragging ? event : null,
                                          ),
                                      child: _AllDayEventChip(
                                        event: event,
                                        centerTitle: centerEventTitles,
                                        height: chipHeight,
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
        ],
      ),
    );
  }
}

class _AllDayEventChip extends StatelessWidget {
  const _AllDayEventChip({
    required this.event,
    required this.centerTitle,
    required this.height,
  });

  final CalendarEvent event;
  final bool centerTitle;
  final double height;

  @override
  Widget build(BuildContext context) {
    final categoryColor = Color(event.colorValue);
    final color = calendarEventAccentColor(
      context,
      categoryColor,
      completed: event.completed,
    );
    final backgroundColor = calendarEventBackgroundColor(
      context,
      categoryColor,
      completed: event.completed,
      categoryAlpha: 0.17,
    );
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(5),
        border: BorderDirectional(start: BorderSide(color: color, width: 3)),
      ),
      child: Text(
        context.l10n.eventTitle(event.title, holiday: event.holiday),
        textAlign: centerTitle ? TextAlign.center : TextAlign.start,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: calendarEventCompletionStyle(
          context,
          Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          completed: event.completed,
        ),
      ),
    );
  }
}

class _ScheduleTimeGrid extends StatelessWidget {
  const _ScheduleTimeGrid({
    required this.days,
    required this.events,
    required this.use24HourTime,
    required this.centerEventTitles,
    required this.eventSortPriority,
    required this.categoryOrder,
    required this.onEventDropped,
    required this.onEventDragStateChanged,
    required this.onDateSelected,
  });

  static const _hourHeight = 64.0;

  final List<DateTime> days;
  final List<CalendarEvent> events;
  final bool use24HourTime;
  final bool centerEventTitles;
  final CalendarEventSortPriority eventSortPriority;
  final List<String> categoryOrder;
  final CalendarEventDropCallback? onEventDropped;
  final ValueChanged<CalendarEvent?> onEventDragStateChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = days.length > 1;
    final gutterWidth = compact ? 42.0 : 54.0;
    final eventComparator = calendarEventComparator(
      priority: eventSortPriority,
      categoryOrder: categoryOrder,
    );
    final layouts = <int, List<_TimelineSegmentLayout>>{
      for (var index = 0; index < days.length; index++)
        index: _layoutSegments(
          _segmentsForDate(events, days[index], eventComparator),
          eventComparator,
        ),
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
                  child: CalendarEventDateDropTarget(
                    date: days[dayIndex],
                    onEventDropped: onEventDropped,
                    borderRadius: BorderRadius.zero,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => onDateSelected(days[dayIndex]),
                    ),
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
    final categoryColor = Color(layout.event.colorValue);
    final color = calendarEventAccentColor(
      context,
      categoryColor,
      completed: layout.event.completed,
    );
    final backgroundColor = calendarEventBackgroundColor(
      context,
      categoryColor,
      completed: layout.event.completed,
      categoryAlpha: 0.18,
    );
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
      child: CalendarEventDraggable(
        event: layout.event,
        enabled: onEventDropped != null,
        onDragStateChanged: (dragging) =>
            onEventDragStateChanged(dragging ? layout.event : null),
        child: Material(
          color: backgroundColor,
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
                      style: calendarEventCompletionStyle(
                        context,
                        const TextStyle(fontWeight: FontWeight.w600),
                        completed: layout.event.completed,
                      ),
                    ),
                    TextSpan(text: '\n$time'),
                  ],
                ),
                maxLines: height >= 42 ? 3 : 1,
                textAlign: centerEventTitles
                    ? TextAlign.center
                    : TextAlign.start,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: color, height: 1.15),
              ),
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
  Comparator<CalendarEvent> eventComparator,
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
    return eventComparator(a.event, b.event);
  });
  return segments;
}

List<_TimelineSegmentLayout> _layoutSegments(
  List<_TimelineSegment> segments,
  Comparator<CalendarEvent> eventComparator,
) {
  final layouts = <_TimelineSegmentLayout>[];
  var offset = 0;
  while (offset < segments.length) {
    var groupEnd = segments[offset].endMinute;
    var end = offset + 1;
    while (end < segments.length && segments[end].startMinute < groupEnd) {
      groupEnd = math.max(groupEnd, segments[end].endMinute);
      end++;
    }
    final group = segments.sublist(offset, end)
      ..sort((a, b) => eventComparator(a.event, b.event));
    final lanes = <List<_TimelineSegment>>[];
    final assigned = <({_TimelineSegment segment, int lane})>[];
    for (final segment in group) {
      var lane = lanes.indexWhere(
        (items) => items.every((item) => !_segmentsOverlap(item, segment)),
      );
      if (lane == -1) {
        lane = lanes.length;
        lanes.add(<_TimelineSegment>[]);
      }
      lanes[lane].add(segment);
      assigned.add((segment: segment, lane: lane));
    }
    for (final item in assigned) {
      layouts.add(
        _TimelineSegmentLayout(
          event: item.segment.event,
          startMinute: item.segment.startMinute,
          endMinute: item.segment.endMinute,
          lane: item.lane,
          laneCount: lanes.length,
        ),
      );
    }
    offset = end;
  }
  return layouts;
}

bool _segmentsOverlap(_TimelineSegment first, _TimelineSegment second) {
  return first.startMinute < second.endMinute &&
      first.endMinute > second.startMinute;
}

List<CalendarEvent> _eventsForDate(
  List<CalendarEvent> events,
  DateTime date,
  Comparator<CalendarEvent> eventComparator,
) {
  final start = DateTime(date.year, date.month, date.day);
  final end = start.add(const Duration(days: 1));
  return events
      .where(
        (event) => event.startAt.isBefore(end) && event.endAt.isAfter(start),
      )
      .toList()
    ..sort(eventComparator);
}

bool _isSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

bool _eventOccursOnDate(CalendarEvent event, DateTime date) {
  final start = DateTime(date.year, date.month, date.day);
  final end = start.add(const Duration(days: 1));
  return event.startAt.isBefore(end) && event.endAt.isAfter(start);
}
