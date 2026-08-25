import 'package:daily/core/calendar/korean_holiday_service.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('holiday events use the configured holiday category color', () {
    final category = EventCategory.holiday.copyWith(colorValue: 0xff10b981);
    final events = KoreanHolidayService().holidayEventsInRange(
      DateTime(2026, 8, 15),
      DateTime(2026, 8, 16),
      category: category,
    );

    expect(events, isNotEmpty);
    expect(events.every((event) => event.category == category), isTrue);
    expect(events.every((event) => event.colorValue == 0xff10b981), isTrue);
  });
}
