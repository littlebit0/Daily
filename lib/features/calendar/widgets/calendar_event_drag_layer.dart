import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/calendar/calendar_event_movement.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/event_completion_style.dart';
import '../../events/domain/calendar_event.dart';

class CalendarEventDraggable extends StatelessWidget {
  const CalendarEventDraggable({
    super.key,
    required this.event,
    required this.child,
    this.enabled = true,
    this.onDragStateChanged,
  });

  final CalendarEvent event;
  final Widget child;
  final bool enabled;
  final ValueChanged<bool>? onDragStateChanged;

  @override
  Widget build(BuildContext context) {
    if (!enabled || !calendarEventCanMove(event)) {
      return child;
    }
    final categoryColor = Color(event.colorValue);
    final accent = calendarEventAccentColor(
      context,
      categoryColor,
      completed: event.completed,
    );
    final background = calendarEventBackgroundColor(
      context,
      categoryColor,
      completed: event.completed,
      categoryAlpha: 0.92,
    );
    final title = context.l10n.eventTitle(event.title, holiday: event.holiday);

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: LongPressDraggable<CalendarEventDragPayload>(
        data: CalendarEventDragPayload(event),
        delay: const Duration(milliseconds: 320),
        allowedButtonsFilter: (buttons) => (buttons & kPrimaryMouseButton) != 0,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: () => onDragStateChanged?.call(true),
        onDragCompleted: () => onDragStateChanged?.call(false),
        onDraggableCanceled: (_, _) => onDragStateChanged?.call(false),
        onDragEnd: (_) => onDragStateChanged?.call(false),
        feedback: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 150, maxWidth: 260),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent, width: 1.4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: calendarEventCompletionStyle(
                    context,
                    TextStyle(color: accent, fontWeight: FontWeight.w800),
                    completed: event.completed,
                  ),
                ),
              ),
            ),
          ),
        ),
        childWhenDragging: IgnorePointer(
          child: Opacity(opacity: 0.25, child: child),
        ),
        child: child,
      ),
    );
  }
}

class CalendarEventDateDropTarget extends StatefulWidget {
  const CalendarEventDateDropTarget({
    super.key,
    required this.date,
    required this.child,
    required this.onEventDropped,
    this.targetIndex = calendarEventAppendIndex,
    this.enabled = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  final DateTime date;
  final Widget child;
  final CalendarEventDropCallback? onEventDropped;
  final int targetIndex;
  final bool enabled;
  final BorderRadius borderRadius;

  @override
  State<CalendarEventDateDropTarget> createState() =>
      _CalendarEventDateDropTargetState();
}

class _CalendarEventDateDropTargetState
    extends State<CalendarEventDateDropTarget> {
  var _hovering = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.onEventDropped == null) {
      return widget.child;
    }
    return DragTarget<CalendarEventDragPayload>(
      onWillAcceptWithDetails: (details) {
        if (!calendarEventCanMove(details.data.event)) {
          return false;
        }
        setState(() => _hovering = true);
        return true;
      },
      onMove: (_) {
        if (!_hovering) {
          setState(() => _hovering = true);
        }
      },
      onLeave: (_) {
        if (_hovering) {
          setState(() => _hovering = false);
        }
      },
      onAcceptWithDetails: (details) {
        if (_hovering) {
          setState(() => _hovering = false);
        }
        unawaited(
          widget.onEventDropped!(
            details.data.event,
            widget.date,
            widget.targetIndex,
          ),
        );
      },
      builder: (context, candidateData, rejectedData) => AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        decoration: BoxDecoration(
          color: _hovering
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.54)
              : Colors.transparent,
          borderRadius: widget.borderRadius,
          border: _hovering
              ? Border.all(color: Theme.of(context).colorScheme.primary)
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

class CalendarEventMonthDropOverlay extends StatelessWidget {
  const CalendarEventMonthDropOverlay({
    super.key,
    required this.focusDate,
    required this.weekStartsOnMonday,
    required this.onEventDropped,
  });

  final DateTime focusDate;
  final bool weekStartsOnMonday;
  final CalendarEventDropCallback onEventDropped;

  @override
  Widget build(BuildContext context) {
    final month = DateTime(focusDate.year, focusDate.month);
    final firstWeekdayOffset = weekStartsOnMonday
        ? month.weekday - DateTime.monday
        : month.weekday % DateTime.daysPerWeek;
    final firstDate = month.subtract(Duration(days: firstWeekdayOffset));
    final days = List.generate(
      42,
      (index) => firstDate.add(Duration(days: index)),
    );
    final firstWeekday = weekStartsOnMonday ? DateTime.monday : DateTime.sunday;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;

    return Material(
      key: const ValueKey('event-date-drop-overlay'),
      color: scheme.surface.withValues(alpha: 0.98),
      elevation: 8,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.drag_indicator, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('일정을 놓을 날짜'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  DateFormat.yMMMM(locale).format(month),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var index = 0; index < 7; index++)
                  Expanded(
                    child: Text(
                      DateFormat.E(
                        locale,
                      ).format(DateTime(2024, 1, firstWeekday + index)),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Column(
                children: [
                  for (var week = 0; week < 6; week++)
                    Expanded(
                      child: Row(
                        children: [
                          for (var weekday = 0; weekday < 7; weekday++)
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final day = days[week * 7 + weekday];
                                  final inMonth = day.month == month.month;
                                  final isSourceDay = _sameDate(day, focusDate);
                                  return Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: CalendarEventDateDropTarget(
                                      key: ValueKey(
                                        'event-date-drop-${day.year}-${day.month}-${day.day}',
                                      ),
                                      date: day,
                                      onEventDropped: onEventDropped,
                                      borderRadius: BorderRadius.circular(7),
                                      child: Center(
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isSourceDay
                                                ? scheme.secondaryContainer
                                                : Colors.transparent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '${day.day}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  color: inMonth
                                                      ? scheme.onSurface
                                                      : scheme.outline,
                                                  fontWeight: isSourceDay
                                                      ? FontWeight.w800
                                                      : FontWeight.w500,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
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

bool _sameDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
