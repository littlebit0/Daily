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
    this.allDay = false,
    this.category = EventCategory.other,
    this.colorValue,
    this.reminderMinutesBefore = 60,
    this.recurrence = const RecurrenceRule(),
  });

  final String title;
  final String? memo;
  final String? location;
  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;
  final EventCategory category;
  final int? colorValue;
  final int? reminderMinutesBefore;
  final RecurrenceRule recurrence;

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
    );
  }

  EventDraft copyWith({
    String? title,
    String? memo,
    String? location,
    DateTime? startAt,
    DateTime? endAt,
    bool? allDay,
    EventCategory? category,
    int? colorValue,
    int? reminderMinutesBefore,
    RecurrenceRule? recurrence,
    bool clearMemo = false,
    bool clearLocation = false,
    bool clearReminder = false,
  }) {
    return EventDraft(
      title: title ?? this.title,
      memo: clearMemo ? null : memo ?? this.memo,
      location: clearLocation ? null : location ?? this.location,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      allDay: allDay ?? this.allDay,
      category: category ?? this.category,
      colorValue: colorValue ?? this.colorValue,
      reminderMinutesBefore: clearReminder
          ? null
          : reminderMinutesBefore ?? this.reminderMinutesBefore,
      recurrence: recurrence ?? this.recurrence,
    );
  }
}
