import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/maps/map_launcher.dart';
import '../domain/calendar_event.dart';
import '../domain/event_category.dart';
import '../domain/event_draft.dart';
import '../domain/recurrence_rule.dart';
import 'event_editor_dialog.dart';
import 'sensitive_event_access.dart';

enum _RecurringChangeScope { onlyThis, future, all }

class EventDetailsPanel extends ConsumerWidget {
  const EventDetailsPanel({
    super.key,
    required this.date,
    required this.events,
    this.scrollController,
  });

  final DateTime date;
  final List<CalendarEvent> events;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final hideSensitive = !ref.watch(sensitiveEventsUnlockedProvider);
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
                    settings.defaultReminderMinutesList,
                  ),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: dayEvents.isEmpty
                  ? ListView(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Text(
                          '일정이 없습니다.',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    )
                  : ListView.separated(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final event = dayEvents[index];
                        return _EventTile(
                          event: event,
                          hideSensitive: hideSensitive,
                          onOpen: () => _openEventDetails(
                            context,
                            ref,
                            event,
                            settings.categories,
                            settings.defaultReminderMinutesList,
                          ),
                          onEdit: event.readOnly
                              ? null
                              : () => _editEvent(
                                  context,
                                  ref,
                                  event,
                                  settings.categories,
                                  settings.defaultReminderMinutesList,
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

  Future<void> _openEventDetails(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
    List<EventCategory> categories,
    List<int> defaultReminderMinutesList,
  ) async {
    if (event.sensitive && !ref.read(sensitiveEventsUnlockedProvider)) {
      final authenticated = await authenticateSensitiveEventAccess(
        context: context,
        ref: ref,
      );
      if (!context.mounted || !authenticated) {
        return;
      }
      ref.read(sensitiveEventsUnlockedProvider.notifier).state = true;
    }
    if (!context.mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _EventDetailSheet(
        event: event,
        onEdit: event.readOnly
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                unawaited(
                  _editEvent(
                    context,
                    ref,
                    event,
                    categories,
                    defaultReminderMinutesList,
                  ),
                );
              },
        onDelete: event.readOnly
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                unawaited(_deleteEvent(context, ref, event));
              },
      ),
    );
  }

  Future<void> _addEvent(
    BuildContext context,
    WidgetRef ref,
    List<EventCategory> categories,
    List<int> defaultReminderMinutesList,
  ) async {
    final draft = await showDialog<EventDraft>(
      context: context,
      builder: (_) => EventEditorDialog(
        initialDate: date,
        categories: categories,
        defaultReminderMinutesList: defaultReminderMinutesList,
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
    List<int> defaultReminderMinutesList,
  ) async {
    final commandService = ref.read(eventCommandServiceProvider);
    final draft = await showDialog<EventDraft>(
      context: context,
      builder: (_) => EventEditorDialog(
        initialDate: event.startAt,
        event: event,
        categories: categories,
        defaultReminderMinutesList: defaultReminderMinutesList,
      ),
    );
    if (draft == null) {
      return;
    }

    if (!event.isRecurring) {
      await commandService.save(_applyDraft(event, draft));
      return;
    }
    if (!context.mounted) {
      return;
    }

    final scope = await _showRecurringScopeDialog(
      context,
      title: '반복 일정 수정',
      actionLabel: '수정',
    );
    if (scope == null) {
      return;
    }

    final base =
        await ref.read(eventRepositoryProvider).findById(event.id) ?? event;
    switch (scope) {
      case _RecurringChangeScope.onlyThis:
        await commandService.save(_excludeOccurrence(base, event.startAt));
        await commandService.create(
          draft.copyWith(recurrence: const RecurrenceRule()),
        );
      case _RecurringChangeScope.future:
        await commandService.save(_endBefore(base, event.startAt));
        await commandService.create(draft);
      case _RecurringChangeScope.all:
        await commandService.save(_applyDraft(base, draft));
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
    if (confirmed != true) {
      return;
    }

    if (event.isRecurring) {
      if (!context.mounted) {
        return;
      }
      final scope = await _showRecurringScopeDialog(
        context,
        title: '반복 일정 삭제',
        actionLabel: '삭제',
      );
      if (scope == null) {
        return;
      }
      final base =
          await ref.read(eventRepositoryProvider).findById(event.id) ?? event;
      switch (scope) {
        case _RecurringChangeScope.onlyThis:
          await commandService.save(_excludeOccurrence(base, event.startAt));
        case _RecurringChangeScope.future:
          await commandService.save(_endBefore(base, event.startAt));
        case _RecurringChangeScope.all:
          await commandService.delete(event.id);
      }
    } else {
      await commandService.delete(event.id);
    }
  }

  CalendarEvent _applyDraft(CalendarEvent event, EventDraft draft) {
    return event.copyWith(
      title: draft.title,
      memo: draft.memo,
      location: draft.location,
      url: draft.url,
      weather: draft.weather,
      startAt: draft.startAt,
      endAt: draft.endAt,
      allDay: draft.allDay,
      category: draft.category,
      colorValue: draft.colorValue ?? draft.category.colorValue,
      reminderMinutesBeforeList: draft.reminderMinutesBeforeList,
      recurrence: draft.recurrence,
      showDday: draft.showDday,
      sensitive: draft.sensitive,
      holiday: draft.category.id == EventCategory.holiday.id,
      clearMemo: draft.memo == null,
      clearLocation: draft.location == null,
      clearUrl: draft.url == null,
      clearWeather: draft.weather == null,
      clearReminder: draft.reminderMinutesBeforeList.isEmpty,
    );
  }

  CalendarEvent _excludeOccurrence(CalendarEvent base, DateTime occurrence) {
    final occurrenceDay = DateTime(
      occurrence.year,
      occurrence.month,
      occurrence.day,
    );
    final excluded = {
      ...base.recurrence.excludedDates.map(
        (date) => DateTime(date.year, date.month, date.day),
      ),
      occurrenceDay,
    }.toList()..sort((a, b) => a.compareTo(b));
    return base.copyWith(
      recurrence: base.recurrence.copyWith(excludedDates: excluded),
    );
  }

  CalendarEvent _endBefore(CalendarEvent base, DateTime occurrence) {
    final until = DateTime(
      occurrence.year,
      occurrence.month,
      occurrence.day,
    ).subtract(const Duration(days: 1));
    return base.copyWith(
      recurrence: base.recurrence.copyWith(until: until, clearCount: true),
    );
  }

  Future<_RecurringChangeScope?> _showRecurringScopeDialog(
    BuildContext context, {
    required String title,
    required String actionLabel,
  }) {
    return showDialog<_RecurringChangeScope>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text('이 반복 일정의 어느 범위에 $actionLabel을 적용할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_RecurringChangeScope.onlyThis),
            child: const Text('이 일정만'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_RecurringChangeScope.future),
            child: const Text('이후 일정'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_RecurringChangeScope.all),
            child: const Text('전체 반복'),
          ),
        ],
      ),
    );
  }

  String _formatDateLabel(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.month}월 ${date.day}일 ${weekdays[date.weekday - 1]}요일';
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.hideSensitive,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final CalendarEvent event;
  final bool hideSensitive;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final hidden = hideSensitive && event.sensitive;
    final timeLabel = _formatTimeLabel(event);
    final color = hidden ? const Color(0xff64748b) : Color(event.colorValue);
    final title = hidden ? '비공개 일정' : event.title;
    return Material(
      color: color.withValues(alpha: event.holiday ? 0.07 : 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withValues(alpha: 0.20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              key: ValueKey('event-open-${event.id}'),
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                                child: Row(
                                  children: [
                                    if (hidden) ...[
                                      const Icon(Icons.lock_outline, size: 16),
                                      const SizedBox(width: 6),
                                    ],
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (event.readOnly)
                                const Icon(Icons.lock_outline, size: 16),
                            ],
                          ),
                          if (!hidden) ...[
                            const SizedBox(height: 4),
                            Text(
                              timeLabel,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                          if (!hidden && event.showDday)
                            Text(
                              _formatDday(event),
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          if (!hidden &&
                              event.location != null &&
                              event.location!.isNotEmpty)
                            Text(
                              event.location!,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          if (!hidden &&
                              event.location != null &&
                              event.location!.isNotEmpty)
                            TextButton.icon(
                              onPressed: () =>
                                  MapLauncher().openLocation(event.location!),
                              icon: const Icon(Icons.map_outlined, size: 16),
                              label: const Text('지도 바로가기'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 28),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          if (!hidden &&
                              event.weather != null &&
                              event.weather!.isNotEmpty)
                            Text(
                              '날씨: ${event.weather!}',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          if (!hidden &&
                              event.url != null &&
                              event.url!.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => _openUrl(event.url!),
                              icon: const Icon(Icons.link, size: 16),
                              label: Text(
                                event.url!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 28),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!hidden && !event.readOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 8, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 48,
                    child: IconButton(
                      key: ValueKey('event-edit-${event.id}'),
                      tooltip: '수정',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                  SizedBox.square(
                    dimension: 48,
                    child: IconButton(
                      key: ValueKey('event-delete-${event.id}'),
                      tooltip: '삭제',
                      onPressed: onDelete == null
                          ? null
                          : () => unawaited(onDelete!()),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String value) async {
    final raw = value.trim();
    final uri = Uri.tryParse(
      raw.startsWith('http://') || raw.startsWith('https://')
          ? raw
          : 'https://$raw',
    );
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

class _EventDetailSheet extends StatelessWidget {
  const _EventDetailSheet({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final CalendarEvent event;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = Color(event.colorValue);
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          event.category.label,
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(color: color),
                        ),
                      ],
                    ),
                  ),
                  if (event.sensitive)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.lock_open_outlined, size: 20),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  children: [
                    _DetailRow(
                      icon: Icons.schedule_outlined,
                      label: '시간',
                      value: _formatTimeLabel(event),
                    ),
                    if (event.location != null && event.location!.isNotEmpty)
                      _DetailActionRow(
                        icon: Icons.location_on_outlined,
                        label: '장소',
                        value: event.location!,
                        actionIcon: Icons.map_outlined,
                        actionLabel: '지도 바로가기',
                        onPressed: () =>
                            MapLauncher().openLocation(event.location!),
                      ),
                    if (event.weather != null && event.weather!.isNotEmpty)
                      _DetailRow(
                        icon: Icons.cloud_outlined,
                        label: '날씨',
                        value: event.weather!,
                      ),
                    if (event.url != null && event.url!.isNotEmpty)
                      _DetailActionRow(
                        icon: Icons.link,
                        label: 'URI',
                        value: event.url!,
                        actionIcon: Icons.open_in_new,
                        actionLabel: '열기',
                        onPressed: () => _openUrl(event.url!),
                      ),
                    if (event.memo != null && event.memo!.isNotEmpty)
                      _DetailRow(
                        icon: Icons.notes_outlined,
                        label: '메모',
                        value: event.memo!,
                      ),
                    if (event.showDday)
                      _DetailRow(
                        icon: Icons.flag_outlined,
                        label: 'D-day',
                        value: _formatDday(event),
                      ),
                    if (event.location == null &&
                        event.weather == null &&
                        event.url == null &&
                        event.memo == null &&
                        !event.showDday)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          '추가 상세정보가 없습니다.',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                  ],
                ),
              ),
              if (onEdit != null || onDelete != null) ...[
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('삭제'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    if (onEdit != null) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('수정'),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeLabel(CalendarEvent event) {
    final dateFormatter = DateFormat('yyyy년 M월 d일');
    final timeFormatter = DateFormat('HH:mm');
    if (event.allDay) {
      final inclusiveEnd = event.endAt.subtract(const Duration(days: 1));
      if (_sameDay(event.startAt, inclusiveEnd)) {
        return '${dateFormatter.format(event.startAt)} 종일';
      }
      return '${dateFormatter.format(event.startAt)} - ${dateFormatter.format(inclusiveEnd)} 종일';
    }
    return '${dateFormatter.format(event.startAt)} ${timeFormatter.format(event.startAt)} - '
        '${dateFormatter.format(event.endAt)} ${timeFormatter.format(event.endAt)}';
  }

  String _formatDday(CalendarEvent event) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      event.startAt.year,
      event.startAt.month,
      event.startAt.day,
    );
    final difference = target.difference(today).inDays;
    if (difference == 0) {
      return 'D-day';
    }
    return difference > 0 ? 'D-$difference' : 'D+${difference.abs()}';
  }

  Future<void> _openUrl(String value) async {
    final raw = value.trim();
    final uri = Uri.tryParse(
      raw.startsWith('http://') || raw.startsWith('https://')
          ? raw
          : 'https://$raw',
    );
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xff64748b)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 3),
                SelectableText(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailActionRow extends StatelessWidget {
  const _DetailActionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.actionIcon,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String value;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xff64748b)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 3),
                SelectableText(value),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onPressed,
            icon: Icon(actionIcon),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
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
