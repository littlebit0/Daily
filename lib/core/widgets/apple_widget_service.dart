import 'dart:io';

import 'package:flutter/services.dart';

import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_repository.dart';
import '../settings/app_settings.dart';
import '../settings/settings_repository.dart';

class AppleWidgetService {
  AppleWidgetService({
    required EventRepository eventRepository,
    required SettingsRepository settingsRepository,
    MethodChannel channel = const MethodChannel('daily/apple_widgets'),
  }) : _eventRepository = eventRepository,
       _settingsRepository = settingsRepository,
       _channel = channel;

  final EventRepository _eventRepository;
  final SettingsRepository _settingsRepository;
  final MethodChannel _channel;

  Future<void> refresh({DateTime? now}) async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return;
    }

    final current = now ?? DateTime.now();
    final settings = _settingsRepository.load();
    final monthStart = DateTime(current.year, current.month);
    final leadingDays = settings.weekStartsOnMonday
        ? monthStart.weekday - DateTime.monday
        : monthStart.weekday % DateTime.daysPerWeek;
    final gridStart = monthStart.subtract(Duration(days: leadingDays));
    final gridEnd = gridStart.add(const Duration(days: 42));

    final results = await Future.wait([
      _eventRepository.eventsInRange(gridStart, gridEnd),
      _eventRepository.allEventsForSync(),
    ]);
    final snapshot = AppleWidgetSnapshotBuilder.build(
      now: current,
      settings: settings,
      gridStart: gridStart,
      monthEvents: results[0],
      allEvents: results[1],
    );

    try {
      await _channel.invokeMethod<void>('updateSnapshot', snapshot);
    } on MissingPluginException {
      // Unit tests and unsupported embedders do not register the Apple bridge.
    } on PlatformException {
      // Widget refresh must never block calendar mutations.
    }
  }
}

class AppleWidgetSnapshotBuilder {
  const AppleWidgetSnapshotBuilder._();

  static Map<String, Object?> build({
    required DateTime now,
    required AppSettings settings,
    required DateTime gridStart,
    required List<CalendarEvent> monthEvents,
    required List<CalendarEvent> allEvents,
  }) {
    final today = _dateOnly(now);
    final weekOffset = settings.weekStartsOnMonday
        ? today.weekday - DateTime.monday
        : today.weekday % DateTime.daysPerWeek;
    final weekStart = today.subtract(Duration(days: weekOffset));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final visibleMonthEvents = monthEvents
        .where((event) => _isVisible(event, settings))
        .toList(growable: false);
    final todayEvents =
        visibleMonthEvents
            .where(
              (event) =>
                  event.overlaps(today, today.add(const Duration(days: 1))),
            )
            .toList()
          ..sort((left, right) {
            if (left.allDay != right.allDay) {
              return left.allDay ? -1 : 1;
            }
            return left.startAt.compareTo(right.startAt);
          });

    final ddayEvents =
        allEvents
            .where((event) => event.showDday && _isVisible(event, settings))
            .toList()
          ..sort((left, right) {
            final leftDistance = _dateOnly(
              left.startAt,
            ).difference(today).inDays.abs();
            final rightDistance = _dateOnly(
              right.startAt,
            ).difference(today).inDays.abs();
            final distanceOrder = leftDistance.compareTo(rightDistance);
            return distanceOrder != 0
                ? distanceOrder
                : left.startAt.compareTo(right.startAt);
          });

    return {
      'generatedAt': now.millisecondsSinceEpoch,
      'monthTitle': '${now.year}년 ${now.month}월',
      'weekTitle': weekStart.month == weekEnd.month
          ? '${weekStart.month}월 ${weekStart.day}일 - ${weekEnd.day}일'
          : '${weekStart.month}월 ${weekStart.day}일 - ${weekEnd.month}월 ${weekEnd.day}일',
      'weekStartsOnMonday': settings.weekStartsOnMonday,
      'monthDays': List.generate(42, (index) {
        final date = gridStart.add(Duration(days: index));
        final dayStart = _dateOnly(date);
        final dayEnd = dayStart.add(const Duration(days: 1));
        final events =
            visibleMonthEvents
                .where((event) => event.overlaps(dayStart, dayEnd))
                .toList()
              ..sort((left, right) {
                if (left.allDay != right.allDay) {
                  return left.allDay ? -1 : 1;
                }
                return left.startAt.compareTo(right.startAt);
              });
        return {
          'date': _dateKey(date),
          'day': date.day,
          'inMonth': date.year == now.year && date.month == now.month,
          'isToday': dayStart == today,
          'eventCount': events.length,
          'events': events
              .map(
                (event) => {
                  'id': event.occurrenceId ?? event.id,
                  'title': _widgetTitle(event),
                  'color': event.colorValue,
                },
              )
              .toList(growable: false),
        };
      }),
      'todayTitle': '${now.month}월 ${now.day}일',
      'todayEvents': todayEvents
          .take(8)
          .map(_eventJson)
          .toList(growable: false),
      'todayRemainingCount': todayEvents.length > 8
          ? todayEvents.length - 8
          : 0,
      'scheduleEvents':
          (visibleMonthEvents.toList()..sort((left, right) {
                if (left.allDay != right.allDay) {
                  return left.allDay ? -1 : 1;
                }
                return left.startAt.compareTo(right.startAt);
              }))
              .map(_eventJson)
              .toList(growable: false),
      'ddays': ddayEvents
          .take(6)
          .map((event) {
            final target = _dateOnly(event.startAt);
            final remaining = target.difference(today).inDays;
            return {
              'id': event.id,
              'title': _widgetTitle(event),
              'dateLabel':
                  '${target.year}.${_two(target.month)}.${_two(target.day)}',
              'daysRemaining': remaining,
              'color': event.colorValue,
            };
          })
          .toList(growable: false),
    };
  }

  static bool _isVisible(CalendarEvent event, AppSettings settings) {
    if (event.isDeleted ||
        settings.hiddenCategoryIds.contains(event.category.id)) {
      return false;
    }
    if (event.holiday && !settings.calendarShowHolidays) {
      return false;
    }
    return true;
  }

  static Map<String, Object?> _eventJson(CalendarEvent event) {
    return {
      'id': event.occurrenceId ?? event.id,
      'title': _widgetTitle(event),
      'timeLabel': event.allDay
          ? '종일'
          : '${_two(event.startAt.hour)}:${_two(event.startAt.minute)}',
      'color': event.colorValue,
      'startAt': event.startAt.millisecondsSinceEpoch,
      'endAt': event.endAt.millisecondsSinceEpoch,
      'allDay': event.allDay,
    };
  }

  static String _widgetTitle(CalendarEvent event) {
    return event.sensitive ? '비공개 일정' : event.title;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String _dateKey(DateTime value) {
    return '${value.year}-${_two(value.month)}-${_two(value.day)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
