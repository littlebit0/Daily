import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/events/presentation/event_details_panel.dart';
import 'package:daily/features/events/presentation/event_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('event detail shows all fields and actions', (tester) async {
    final event = _event();
    await _pumpPanel(tester, event: event);

    await tester.tap(find.text('비밀 회의').first);
    await tester.pumpAndSettle();

    expect(find.text('시간'), findsOneWidget);
    expect(find.text('장소'), findsOneWidget);
    expect(find.text('서울시청'), findsWidgets);
    expect(find.text('지도 바로가기'), findsWidgets);
    expect(find.text('URI'), findsOneWidget);
    expect(find.text('https://example.com/meeting'), findsWidgets);
    expect(find.text('날씨'), findsOneWidget);
    expect(find.text('맑음'), findsWidgets);
    expect(find.text('메모'), findsOneWidget);
    expect(find.text('준비물 확인'), findsWidgets);
    expect(find.text('수정'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
  });

  testWidgets('event card and action boxes respond across their full bounds', (
    tester,
  ) async {
    final event = _event();
    await _pumpPanel(tester, event: event);

    final openArea = find.byKey(ValueKey('event-open-${event.id}'));
    for (final point in _insetCorners(tester.getRect(openArea))) {
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(find.text('시간'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
    }

    final editArea = find.byKey(ValueKey('event-edit-${event.id}'));
    for (final point in _insetCorners(tester.getRect(editArea))) {
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(find.byType(EventEditorDialog), findsOneWidget);
      await tester.tap(find.text('취소').last);
      await tester.pumpAndSettle();
    }

    final deleteArea = find.byKey(ValueKey('event-delete-${event.id}'));
    for (final point in _insetCorners(tester.getRect(deleteArea))) {
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(find.text('일정 삭제'), findsOneWidget);
      await tester.tap(find.text('취소').last);
      await tester.pumpAndSettle();
    }
  });
}

List<Offset> _insetCorners(Rect rect) => [
  rect.topLeft + const Offset(4, 4),
  rect.topRight + const Offset(-4, 4),
  rect.bottomLeft + const Offset(4, -4),
  rect.bottomRight + const Offset(-4, -4),
];

Future<void> _pumpPanel(
  WidgetTester tester, {
  required CalendarEvent event,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final repository = _SingleEventRepository(event);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(
          SettingsRepository(preferences: preferences),
        ),
        eventRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: EventDetailsPanel(date: event.startAt, events: [event]),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

CalendarEvent _event() {
  return CalendarEvent(
    id: 'meeting-event',
    title: '비밀 회의',
    memo: '준비물 확인',
    location: '서울시청',
    url: 'https://example.com/meeting',
    weather: '맑음',
    startAt: DateTime(2026, 7, 17, 10),
    endAt: DateTime(2026, 7, 17, 11),
    allDay: false,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    createdAt: DateTime(2026, 7, 16),
    updatedAt: DateTime(2026, 7, 16),
  );
}

class _SingleEventRepository implements EventRepository {
  _SingleEventRepository(this.event);

  CalendarEvent event;

  @override
  Future<List<CalendarEvent>> allEventsForSync() async => [event];

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> delete(String eventId) async {}

  @override
  Future<List<CalendarEvent>> eventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async => [event];

  @override
  Future<CalendarEvent?> findById(String id) async => event;

  @override
  Future<void> hardDelete(String eventId) async {}

  @override
  Future<void> markSynced(String eventId) async {}

  @override
  Future<List<CalendarEvent>> pendingSyncEvents() async => [event];

  @override
  Future<void> save(CalendarEvent event) async {
    this.event = event;
  }

  @override
  Future<List<CalendarEvent>> search(String query) async => [event];

  @override
  Future<List<CalendarEvent>> updateCategoryReferences({
    required EventCategory previous,
    required EventCategory updated,
    required DateTime updatedAt,
  }) async => const [];

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) => Stream.value([event]);
}
