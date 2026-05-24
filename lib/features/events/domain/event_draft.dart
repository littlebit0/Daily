import 'calendar_event.dart';
import 'event_category.dart';
import 'recurrence_rule.dart';

class EventDraft {
  const EventDraft({
    required this.title,
    required this.startAt,
    required this.endAt,
    this.memo,
    this.location,
    this.url,
    this.weather,
    this.allDay = false,
    this.category = EventCategory.other,
    this.colorValue,
    this.reminderMinutesBefore = 60,
    this.recurrence = const RecurrenceRule(),
    this.showDday = false,
    this.sensitive = false,
  });

  final String title;
  final String? memo;
  final String? location;
  final String? url;
  final String? weather;
  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;
  final EventCategory category;
  final int? colorValue;
  final int? reminderMinutesBefore;
  final RecurrenceRule recurrence;
  final bool showDday;
  final bool sensitive;

  CalendarEvent toEvent({
    required String id,
    required DateTime now,
    required String deviceId,
  }) {
    final resolvedColor = colorValue ?? category.colorValue;
    return CalendarEvent(
      id: id,
      title: title,
      memo: memo,
      location: location,
      url: url,
      weather: weather,
      startAt: startAt,
      endAt: endAt,
      allDay: allDay,
      category: category,
      colorValue: resolvedColor,
      reminderMinutesBefore: reminderMinutesBefore,
      recurrence: recurrence,
      createdAt: now,
      updatedAt: now,
      deviceId: deviceId,
      syncStatus: 'pending',
      showDday: showDday,
      sensitive: sensitive,
    );
  }

  EventDraft copyWith({
    String? title,
    String? memo,
    String? location,
    String? url,
    String? weather,
    DateTime? startAt,
    DateTime? endAt,
    bool? allDay,
    EventCategory? category,
    int? colorValue,
    int? reminderMinutesBefore,
    RecurrenceRule? recurrence,
    bool? showDday,
    bool? sensitive,
    bool clearMemo = false,
    bool clearLocation = false,
    bool clearUrl = false,
    bool clearWeather = false,
    bool clearReminder = false,
  }) {
    return EventDraft(
      title: title ?? this.title,
      memo: clearMemo ? null : memo ?? this.memo,
      location: clearLocation ? null : location ?? this.location,
      url: clearUrl ? null : url ?? this.url,
      weather: clearWeather ? null : weather ?? this.weather,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      allDay: allDay ?? this.allDay,
      category: category ?? this.category,
      colorValue: colorValue ?? this.colorValue,
      reminderMinutesBefore: clearReminder
          ? null
          : reminderMinutesBefore ?? this.reminderMinutesBefore,
      recurrence: recurrence ?? this.recurrence,
      showDday: showDday ?? this.showDday,
      sensitive: sensitive ?? this.sensitive,
    );
  }
}
