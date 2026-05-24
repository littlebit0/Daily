import 'event_category.dart';
import 'recurrence_rule.dart';

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.allDay,
    required this.category,
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
    this.occurrenceId,
    this.memo,
    this.location,
    this.url,
    this.weather,
    this.reminderMinutesBefore,
    this.recurrence = const RecurrenceRule(),
    this.deletedAt,
    this.deviceId = '',
    this.syncStatus = 'pending',
    this.showDday = false,
    this.sensitive = false,
    this.readOnly = false,
    this.systemEvent = false,
    this.holiday = false,
  });

  final String id;
  final String? occurrenceId;
  final String title;
  final String? memo;
  final String? location;
  final String? url;
  final String? weather;
  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;
  final EventCategory category;
  final int colorValue;
  final int? reminderMinutesBefore;
  final RecurrenceRule recurrence;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
  final String syncStatus;
  final bool showDday;
  final bool sensitive;
  final bool readOnly;
  final bool systemEvent;
  final bool holiday;

  Duration get duration => endAt.difference(startAt);

  bool get isDeleted => deletedAt != null;

  bool get isRecurring => recurrence.isRepeating;

  bool overlaps(DateTime rangeStart, DateTime rangeEnd) {
    return startAt.isBefore(rangeEnd) && endAt.isAfter(rangeStart);
  }

  CalendarEvent copyWith({
    String? id,
    String? occurrenceId,
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
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? deviceId,
    String? syncStatus,
    bool? showDday,
    bool? sensitive,
    bool? readOnly,
    bool? systemEvent,
    bool? holiday,
    bool clearOccurrenceId = false,
    bool clearMemo = false,
    bool clearLocation = false,
    bool clearUrl = false,
    bool clearWeather = false,
    bool clearReminder = false,
    bool clearDeletedAt = false,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      occurrenceId: clearOccurrenceId
          ? null
          : occurrenceId ?? this.occurrenceId,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      syncStatus: syncStatus ?? this.syncStatus,
      showDday: showDday ?? this.showDday,
      sensitive: sensitive ?? this.sensitive,
      readOnly: readOnly ?? this.readOnly,
      systemEvent: systemEvent ?? this.systemEvent,
      holiday: holiday ?? this.holiday,
    );
  }
}
