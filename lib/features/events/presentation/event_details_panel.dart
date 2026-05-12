import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/app_providers.dart';
import '../domain/calendar_event.dart';
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
    final dateLabel = DateFormat('M월 d일 EEEE', 'ko').format(date);
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
                  onPressed: () => _addEvent(context, ref),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (events.isEmpty)
              Text('일정이 없습니다.', style: Theme.of(context).textTheme.labelMedium)
            else
              Expanded(
                child: ListView.separated(
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return _EventTile(
                      event: event,
                      onEdit: () => _editEvent(context, ref, event),
                      onDelete: () => ref
                          .read(eventCommandServiceProvider)
                          .delete(event.id),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemCount: events.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addEvent(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<EventDraft>(
      context: context,
      builder: (_) => EventEditorDialog(initialDate: date),
    );
    if (draft != null) {
      await ref.read(eventCommandServiceProvider).create(draft);
    }
  }

  Future<void> _editEvent(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final draft = await showDialog<EventDraft>(
      context: context,
      builder: (_) =>
          EventEditorDialog(initialDate: event.startAt, event: event),
    );
    if (draft != null) {
      await ref
          .read(eventCommandServiceProvider)
          .save(
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
            ),
          );
    }
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final CalendarEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('HH:mm');
    final timeLabel = event.allDay
        ? '종일'
        : '${formatter.format(event.startAt)} 시작';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(event.colorValue).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Color(event.colorValue).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: Color(event.colorValue),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(timeLabel, style: Theme.of(context).textTheme.labelMedium),
                if (event.location != null && event.location!.isNotEmpty)
                  Text(
                    event.location!,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: '수정',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '삭제',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
