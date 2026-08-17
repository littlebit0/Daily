import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_repository.dart';
import '../settings/app_settings.dart';
import '../settings/settings_repository.dart';
import '../localization/app_localizations.dart';

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
  Future<void>? _refreshInFlight;
  bool _refreshRequested = false;
  DateTime? _requestedNow;

  Future<void> refresh({DateTime? now}) {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return Future.value();
    }

    _refreshRequested = true;
    _requestedNow = now;
    return _refreshInFlight ??= _drainRefreshRequests().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<void> _drainRefreshRequests() async {
    while (_refreshRequested) {
      _refreshRequested = false;
      final now = _requestedNow;
      _requestedNow = null;
      await _refreshOnce(now: now);
    }
  }

  Future<void> _refreshOnce({DateTime? now}) async {
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
    final locale = resolvedLocaleForLanguage(
      settings.language,
      PlatformDispatcher.instance.locale,
    );
    final localeName = locale.toLanguageTag();
    final l10n = AppLocalizations(locale);
    final weekOffset = settings.weekStartsOnMonday
        ? today.weekday - DateTime.monday
        : today.weekday % DateTime.daysPerWeek;
    final weekStart = today.subtract(Duration(days: weekOffset));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final visibleMonthEvents = monthEvents
        .where((event) => _isVisible(event, settings))
        .toList(growable: false);
    final monthEventsByDay = _eventsByDay(
      visibleMonthEvents,
      gridStart,
      gridStart.add(const Duration(days: 42)),
    );
    final todayEvents =
        List<CalendarEvent>.from(monthEventsByDay[_dateKey(today)] ?? const [])
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
      'monthTitle': DateFormat.yMMMM(localeName).format(now),
      'weekTitle':
          '${DateFormat.MMMd(localeName).format(weekStart)} - '
          '${DateFormat.MMMd(localeName).format(weekEnd)}',
      'weekStartsOnMonday': settings.weekStartsOnMonday,
      'monthDays': List.generate(42, (index) {
        final date = gridStart.add(Duration(days: index));
        final dayStart = _dateOnly(date);
        final events = monthEventsByDay[_dateKey(dayStart)] ?? const [];
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
                  'title': l10n.eventTitle(event.title, holiday: event.holiday),
                  'color': event.colorValue,
                },
              )
              .toList(growable: false),
        };
      }),
      'todayTitle': DateFormat.MMMd(localeName).format(now),
      'todayEvents': todayEvents
          .take(8)
          .map((event) => _eventJson(event, l10n))
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
              .map((event) => _eventJson(event, l10n))
              .toList(growable: false),
      'ddays': ddayEvents
          .take(6)
          .map((event) {
            final target = _dateOnly(event.startAt);
            final remaining = target.difference(today).inDays;
            return {
              'id': event.id,
              'title': l10n.eventTitle(event.title, holiday: event.holiday),
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

  static Map<String, List<CalendarEvent>> _eventsByDay(
    List<CalendarEvent> events,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final result = <String, List<CalendarEvent>>{};
    for (final event in events) {
      var cursor = _dateOnly(event.startAt);
      if (cursor.isBefore(rangeStart)) {
        cursor = rangeStart;
      }
      var eventEnd = _dateOnly(
        event.endAt.subtract(const Duration(microseconds: 1)),
      );
      final lastRangeDay = rangeEnd.subtract(const Duration(days: 1));
      if (eventEnd.isAfter(lastRangeDay)) {
        eventEnd = lastRangeDay;
      }
      while (!cursor.isAfter(eventEnd)) {
        result.putIfAbsent(_dateKey(cursor), () => []).add(event);
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    for (final dayEvents in result.values) {
      dayEvents.sort((left, right) {
        if (left.allDay != right.allDay) {
          return left.allDay ? -1 : 1;
        }
        return left.startAt.compareTo(right.startAt);
      });
    }
    return result;
  }

  static Map<String, Object?> _eventJson(
    CalendarEvent event,
    AppLocalizations localizations,
  ) {
    return {
      'id': event.occurrenceId ?? event.id,
      'title': localizations.eventTitle(event.title, holiday: event.holiday),
      'timeLabel': event.allDay
          ? localizations.text('종일')
          : '${_two(event.startAt.hour)}:${_two(event.startAt.minute)}',
      'color': event.colorValue,
      'startAt': event.startAt.millisecondsSinceEpoch,
      'endAt': event.endAt.millisecondsSinceEpoch,
      'allDay': event.allDay,
    };
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String _dateKey(DateTime value) {
    return '${value.year}-${_two(value.month)}-${_two(value.day)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
