import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
import 'package:daily/features/events/data/recurrence_expander.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('range queries do not map unrelated one-time events', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final expander = _CountingRecurrenceExpander();
    final repository = DriftEventRepository(database, expander: expander);

    for (var index = 0; index < 120; index++) {
      await repository.save(
        _event(
          id: 'historical-$index',
          startAt: DateTime(2020, 1, 1).add(Duration(days: index)),
        ),
      );
    }
    await repository.save(
      _event(id: 'visible', startAt: DateTime(2026, 7, 15, 9)),
    );
    await repository.save(
      _event(
        id: 'recurring',
        startAt: DateTime(2020, 1, 6, 9),
        recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.weekly),
      ),
    );

    final rangeStart = DateTime(2026, 7, 1);
    final rangeEnd = DateTime(2026, 8, 1);
    final events = await repository.eventsInRange(rangeStart, rangeEnd);

    expect(expander.calls, 2);
    expect(events.any((event) => event.id == 'visible'), isTrue);
    expect(events.any((event) => event.id == 'recurring'), isTrue);

    expander.calls = 0;
    await repository.watchEventsInRange(rangeStart, rangeEnd).first;
    expect(expander.calls, 2);
  });
}

CalendarEvent _event({
  required String id,
  required DateTime startAt,
  RecurrenceRule recurrence = const RecurrenceRule(),
}) {
  return CalendarEvent(
    id: id,
    title: id,
    startAt: startAt,
    endAt: startAt.add(const Duration(hours: 1)),
    allDay: false,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    recurrence: recurrence,
    createdAt: startAt,
    updatedAt: startAt,
  );
}

class _CountingRecurrenceExpander extends RecurrenceExpander {
  var calls = 0;

  @override
  List<CalendarEvent> expand(
    CalendarEvent event,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    calls += 1;
    return super.expand(event, rangeStart, rangeEnd);
  }
}
