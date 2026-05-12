import 'app_database.dart';
import '../domain/calendar_event.dart';
import '../domain/event_category.dart';
import '../domain/recurrence_rule.dart';

extension EventRecordMapper on EventRecord {
  CalendarEvent toDomain({DateTime? occurrenceStart}) {
    final baseStart = occurrenceStart ?? startAt;
    final duration = endAt.difference(startAt);
    return CalendarEvent(
      id: id,
      occurrenceId: occurrenceStart == null
          ? null
          : '$id@${occurrenceStart.toIso8601String()}',
      title: title,
      memo: memo,
      location: location,
      startAt: baseStart,
      endAt: baseStart.add(duration),
      allDay: allDay,
      category: EventCategory.fromName(category),
      colorValue: colorValue,
      reminderMinutesBefore: reminderMinutesBefore,
      recurrence: RecurrenceRule(
        frequency: RecurrenceFrequency.fromName(recurrenceFrequency),
        interval: recurrenceInterval,
        until: recurrenceUntil,
        count: recurrenceCount,
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      deviceId: deviceId,
      syncStatus: syncStatus,
    );
  }
}
