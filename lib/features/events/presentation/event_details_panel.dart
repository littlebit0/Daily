import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/app_providers.dart';
import '../domain/calendar_event.dart';
import '../domain/event_category.dart';
import '../domain/event_draft.dart';
import 'event_editor_dialog.dart';

class EventDetailsPanel extends ConsumerWidget {
  const EventDetailsPanel({
    super.key,
    required this.date,
    required this.events,
  });

  final DateTime date;
  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final dateLabel = _formatDateLabel(date);
    final liveEventsAsync = ref.watch(eventsInRangeProvider(_dayRange(date)));
    final dayEvents = liveEventsAsync.maybeWhen(
      data: (items) => _eventsForDay(items, date),
      orElse: () => events,
    );

    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: '일정 추가',
                  onPressed: () => _addEvent(
                    context,
                    ref,
                    settings.categories,
                    settings.defaultReminderMinutes,
                  ),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (dayEvents.isEmpty)
              Text('일정이 없습니다.', style: Theme.of(context).textTheme.labelMedium)
            else
              Expanded(
                child: ListView.separated(
                  itemBuilder: (context, index) {
                    final event = dayEvents[index];
                    return _EventTile(
                      event: event,
                      onEdit: event.readOnly
                          ? null
                          : () => _editEvent(
                              context,
                              ref,
                              event,
                              settings.categories,
                              settings.defaultReminderMinutes,
                            ),
                      onDelete: event.readOnly
                          ? null
                          : () => _deleteEvent(context, ref, event),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemCount: dayEvents.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addEvent(
    BuildContext context,
    WidgetRef ref,
    List<EventCategory> categories,
    int defaultReminderMinutes,
  ) async {
    final draft = await showDialog<EventDraft>(
      context: context,
      builder: (_) => EventEditorDialog(
        initialDate: date,
        categories: categories,
        defaultReminderMinutes: defaultReminderMinutes,
      ),
    );
    if (draft != null) {
      await ref.read(eventCommandServiceProvider).create(draft);
    }
  }

  Future<void> _editEvent(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
    List<EventCategory> categories,
    int defaultReminderMinutes,
  ) async {
    final commandService = ref.read(eventCommandServiceProvider);
    final draft = await showDialog<EventDraft>(
      context: context,
      builder: (_) => EventEditorDialog(
        initialDate: event.startAt,
        event: event,
        categories: categories,
        defaultReminderMinutes: defaultReminderMinutes,
      ),
    );
    if (draft != null) {
      await commandService.save(
        event.copyWith(
          title: draft.title,
          memo: draft.memo,
          location: draft.location,
          startAt: draft.startAt,
          endAt: draft.endAt,
          allDay: draft.allDay,
          category: draft.category,
          colorValue: draft.colorValue ?? draft.category.colorValue,
          reminderMinutesBefore: draft.reminderMinutesBefore,
          recurrence: draft.recurrence,
          showDday: draft.showDday,
          clearMemo: draft.memo == null,
          clearLocation: draft.location == null,
          clearReminder: draft.reminderMinutesBefore == null,
        ),
      );
    }
  }

  Future<void> _deleteEvent(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final commandService = ref.read(eventCommandServiceProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text('"${event.title}" 일정을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await commandService.delete(event.id);
    }
  }

  String _formatDateLabel(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.month}월 ${date.day}일 ${weekdays[date.weekday - 1]}요일';
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final CalendarEvent event;
  final VoidCallback? onEdit;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final timeLabel = _formatTimeLabel(event);
    final color = Color(event.colorValue);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: event.holiday ? 0.07 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (event.readOnly)
                      const Icon(Icons.lock_outline, size: 16),
                  ],
                ),
                const SizedBox(height: 4),
                Text(timeLabel, style: Theme.of(context).textTheme.labelMedium),
                if (event.showDday)
                  Text(
                    _formatDday(event),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (event.location != null && event.location!.isNotEmpty)
                  Text(
                    event.location!,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
              ],
            ),
          ),
          if (!event.readOnly) ...[
            IconButton(
              tooltip: '수정',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: '삭제',
              onPressed: onDelete == null ? null : () => unawaited(onDelete!()),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimeLabel(CalendarEvent event) {
    final dateFormatter = DateFormat('M월 d일');
    final timeFormatter = DateFormat('HH:mm');
    if (event.allDay) {
      final inclusiveEnd = event.endAt.subtract(const Duration(days: 1));
      if (_sameDay(event.startAt, inclusiveEnd)) {
        return '종일';
      }
      return '${dateFormatter.format(event.startAt)} - ${dateFormatter.format(inclusiveEnd)} 종일';
    }
    if (_sameDay(event.startAt, event.endAt)) {
      return '${timeFormatter.format(event.startAt)} - ${timeFormatter.format(event.endAt)}';
    }
    return '${dateFormatter.format(event.startAt)} ${timeFormatter.format(event.startAt)} - ${dateFormatter.format(event.endAt)} ${timeFormatter.format(event.endAt)}';
  }

  String _formatDday(CalendarEvent event) {
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    final target = DateTime(
      event.startAt.year,
      event.startAt.month,
      event.startAt.day,
    );
    final diff = target.difference(base).inDays;
    if (diff == 0) {
      return 'D-day';
    }
    return diff > 0 ? 'D-$diff' : 'D+${diff.abs()}';
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

CalendarRange _dayRange(DateTime date) {
  final start = DateTime(date.year, date.month, date.day);
  return CalendarRange(start, start.add(const Duration(days: 1)));
}

List<CalendarEvent> _eventsForDay(List<CalendarEvent> events, DateTime date) {
  final start = DateTime(date.year, date.month, date.day);
  final end = start.add(const Duration(days: 1));
  return events
      .where(
        (event) => event.startAt.isBefore(end) && event.endAt.isAfter(start),
      )
      .toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
}
