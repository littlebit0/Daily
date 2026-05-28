import 'package:daily/core/notifications/reminder_delivery_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'schedules the requested reminder time when it is still in the future',
    () {
      final now = DateTime(2026, 5, 29, 9);
      final reminderAt = now.add(const Duration(minutes: 10));

      final plan = resolveReminderDeliveryPlan(
        reminderAt: reminderAt,
        fallbackAt: now.add(const Duration(hours: 1)),
        eventEndAt: now.add(const Duration(hours: 2)),
        now: now,
        allowImmediate: true,
      );

      expect(plan.type, ReminderDeliveryType.scheduled);
      expect(plan.deliverAt, reminderAt);
    },
  );

  test(
    'immediately delivers a newly saved ongoing event whose reminder is late',
    () {
      final now = DateTime(2026, 5, 29, 9, 10);
      final reminderAt = now.subtract(const Duration(minutes: 10));

      final plan = resolveReminderDeliveryPlan(
        reminderAt: reminderAt,
        fallbackAt: now.subtract(const Duration(minutes: 10)),
        eventEndAt: now.add(const Duration(hours: 1)),
        now: now,
        allowImmediate: true,
      );

      expect(plan.type, ReminderDeliveryType.immediate);
      expect(plan.deliverAt, reminderAt);
    },
  );

  test(
    'immediately delivers when a new event is inside an already missed reminder window',
    () {
      final now = DateTime(2026, 5, 29, 9, 55);
      final startsAt = DateTime(2026, 5, 29, 10);
      final reminderAt = startsAt.subtract(const Duration(hours: 1));

      final plan = resolveReminderDeliveryPlan(
        reminderAt: reminderAt,
        fallbackAt: startsAt,
        eventEndAt: startsAt.add(const Duration(hours: 1)),
        now: now,
        allowImmediate: true,
      );

      expect(plan.type, ReminderDeliveryType.immediate);
      expect(plan.deliverAt, reminderAt);
    },
  );

  test(
    'startup reschedule falls back to event start without immediate spam',
    () {
      final now = DateTime(2026, 5, 29, 9, 55);
      final startsAt = DateTime(2026, 5, 29, 10);
      final reminderAt = startsAt.subtract(const Duration(hours: 1));

      final plan = resolveReminderDeliveryPlan(
        reminderAt: reminderAt,
        fallbackAt: startsAt,
        eventEndAt: startsAt.add(const Duration(hours: 1)),
        now: now,
        allowImmediate: false,
      );

      expect(plan.type, ReminderDeliveryType.scheduled);
      expect(plan.deliverAt, startsAt);
    },
  );

  test('startup reschedule does not re-emit a just-fired reminder', () {
    final now = DateTime(2026, 5, 29, 10, 1);
    final startsAt = DateTime(2026, 5, 29, 10);

    final plan = resolveReminderDeliveryPlan(
      reminderAt: startsAt,
      fallbackAt: startsAt,
      eventEndAt: startsAt.add(const Duration(hours: 1)),
      now: now,
      allowImmediate: false,
    );

    expect(plan.type, ReminderDeliveryType.none);
    expect(plan.deliverAt, isNull);
  });

  test('skips ended events whose reminder and fallback are both stale', () {
    final now = DateTime(2026, 5, 29, 12);

    final plan = resolveReminderDeliveryPlan(
      reminderAt: now.subtract(const Duration(hours: 3)),
      fallbackAt: now.subtract(const Duration(hours: 2)),
      eventEndAt: now.subtract(const Duration(hours: 1)),
      now: now,
      allowImmediate: true,
    );

    expect(plan.type, ReminderDeliveryType.none);
    expect(plan.deliverAt, isNull);
  });
}
