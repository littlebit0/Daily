import 'dart:async';
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
    Duration themeRefreshDelay = const Duration(milliseconds: 400),
  }) : _eventRepository = eventRepository,
       _settingsRepository = settingsRepository,
       _channel = channel,
       _themeRefreshDelay = themeRefreshDelay {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  final EventRepository _eventRepository;
  final SettingsRepository _settingsRepository;
  final MethodChannel _channel;
  final Duration _themeRefreshDelay;
  final _todoActionChanges = StreamController<void>.broadcast(sync: true);
  Future<void>? _refreshInFlight;
  bool _refreshRequested = false;
  DateTime? _requestedNow;
  int _themeRefreshGeneration = 0;
  bool _disposed = false;

  Stream<void> get todoActionChanges => _todoActionChanges.stream;

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method == 'todoActionsChanged' && !_todoActionChanges.isClosed) {
      _todoActionChanges.add(null);
    }
    return null;
  }

  void dispose() {
    _disposed = true;
    _themeRefreshGeneration += 1;
    _channel.setMethodCallHandler(null);
    unawaited(_todoActionChanges.close());
  }

  Future<List<AppleWidgetTodoAction>> pendingTodoActions() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return const [];
    }
    try {
      final raw = await _channel.invokeListMethod<Object?>(
        'pendingTodoActions',
      );
      return (raw ?? const [])
          .whereType<Map<Object?, Object?>>()
          .map(AppleWidgetTodoAction.fromMap)
          .whereType<AppleWidgetTodoAction>()
          .toList(growable: false);
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  Future<void> acknowledgeTodoActions(Iterable<String> tokens) async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return;
    }
    final values = tokens.where((token) => token.isNotEmpty).toList();
    if (values.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('acknowledgeTodoActions', {
        'tokens': values,
      });
    } on MissingPluginException {
      // Unsupported embedders have no pending widget actions.
    } on PlatformException {
      // Leave actions pending so a later app resume can retry them.
    }
  }

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

  Future<void> refreshTheme({DateTime? now}) async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return;
    }

    final generation = ++_themeRefreshGeneration;
    await Future<void>.delayed(_themeRefreshDelay);
    if (_disposed || generation != _themeRefreshGeneration) {
      return;
    }
    await refresh(now: now);
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
      'themeMode': settings.themeMode.name,
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
                  'eventId': event.id,
                  'title': l10n.eventTitle(event.title, holiday: event.holiday),
                  'color': event.colorValue,
                  'completed': event.completed,
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
              'completed': event.completed,
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
      'eventId': event.id,
      'title': localizations.eventTitle(event.title, holiday: event.holiday),
      'timeLabel': event.allDay
          ? localizations.text('종일')
          : '${_two(event.startAt.hour)}:${_two(event.startAt.minute)}',
      'color': event.colorValue,
      'startAt': event.startAt.millisecondsSinceEpoch,
      'endAt': event.endAt.millisecondsSinceEpoch,
      'allDay': event.allDay,
      'completed': event.completed,
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

class AppleWidgetTodoAction {
  const AppleWidgetTodoAction({
    required this.token,
    required this.eventId,
    required this.completed,
  });

  final String token;
  final String eventId;
  final bool completed;

  static AppleWidgetTodoAction? fromMap(Map<Object?, Object?> map) {
    final token = map['token'];
    final eventId = map['eventId'];
    final completed = map['completed'];
    if (token is! String || eventId is! String || completed is! bool) {
      return null;
    }
    return AppleWidgetTodoAction(
      token: token,
      eventId: eventId,
      completed: completed,
    );
  }
}
