enum ReminderDeliveryType { none, immediate, scheduled }

class ReminderDeliveryPlan {
  const ReminderDeliveryPlan._(this.type, this.deliverAt);

  const ReminderDeliveryPlan.none() : this._(ReminderDeliveryType.none, null);

  const ReminderDeliveryPlan.immediate(DateTime deliverAt)
    : this._(ReminderDeliveryType.immediate, deliverAt);

  const ReminderDeliveryPlan.scheduled(DateTime deliverAt)
    : this._(ReminderDeliveryType.scheduled, deliverAt);

  final ReminderDeliveryType type;
  final DateTime? deliverAt;
}

ReminderDeliveryPlan resolveReminderDeliveryPlan({
  required DateTime reminderAt,
  required DateTime fallbackAt,
  required DateTime eventEndAt,
  required DateTime now,
  required bool allowImmediate,
  Duration dueGrace = const Duration(minutes: 2),
}) {
  if (reminderAt.isAfter(now)) {
    return ReminderDeliveryPlan.scheduled(reminderAt);
  }

  if (allowImmediate && eventEndAt.isAfter(now)) {
    return ReminderDeliveryPlan.immediate(reminderAt);
  }

  if (fallbackAt.isAfter(now)) {
    return ReminderDeliveryPlan.scheduled(fallbackAt);
  }

  if (allowImmediate && now.difference(fallbackAt) <= dueGrace) {
    return ReminderDeliveryPlan.immediate(fallbackAt);
  }

  return const ReminderDeliveryPlan.none();
}
