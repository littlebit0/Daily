import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/calendar/calendar_event_movement.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/events/presentation/event_details_panel.dart';
import 'package:daily/features/events/presentation/event_editor_dialog.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('ko'));

  testWidgets('event detail shows all fields and actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final event = _event();
    final repository = await _pumpPanel(tester, event: event);

    await tester.tap(find.text('비밀 회의').first);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('event-detail-todo-meeting-event')),
      findsOneWidget,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(repository.event.completed, isTrue);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

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

  testWidgets('repeating delete uses the delete-specific all scope label', (
    tester,
  ) async {
    final event = _event().copyWith(
      recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.daily),
    );
    await _pumpPanel(tester, event: event);

    await tester.tap(find.byKey(ValueKey('event-delete-${event.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').last);
    await tester.pumpAndSettle();

    expect(find.text('전체 삭제'), findsOneWidget);
    expect(find.text('전체 반복'), findsNothing);
  });

  testWidgets(
    'long press keeps the day panel visible and exposes an order target',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final event = _event();
      DateTime? droppedDate;
      int? droppedIndex;
      CalendarEvent? droppedEvent;
      final dragStates = <bool>[];
      await _pumpPanel(
        tester,
        event: event,
        onEventDropped: (event, date, index) async {
          droppedEvent = event;
          droppedDate = date;
          droppedIndex = index;
        },
        onEventDragStateChanged: dragStates.add,
      );

      final draggable = find.byKey(const ValueKey('event-drag-meeting-event'));
      final gesture = await tester.startGesture(tester.getCenter(draggable));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const ValueKey('event-date-drop-overlay')),
        findsNothing,
      );
      expect(find.textContaining('2026'), findsWidgets);
      final target = find.byKey(
        const ValueKey('event-order-drop-meeting-event'),
      );
      expect(target, findsOneWidget);
      await gesture.moveTo(tester.getBottomRight(target) - const Offset(8, 4));
      await tester.pump(const Duration(milliseconds: 120));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(droppedDate, DateTime(2026, 7, 17, 10));
      expect(droppedEvent?.id, event.id);
      expect(droppedEvent?.occurrenceId, event.occurrenceId);
      expect(droppedIndex, 1);
      expect(dragStates, containsAllInOrder([true, false]));
    },
  );

  test(
    'all-delete label is translated in every supported non-Korean locale',
    () {
      expect(const AppLocalizations(Locale('en')).text('전체 삭제'), 'Delete All');
      expect(const AppLocalizations(Locale('ja')).text('전체 삭제'), 'すべて削除');
      expect(
        const AppLocalizations(
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ).text('전체 삭제'),
        '全部刪除',
      );
    },
  );
}

List<Offset> _insetCorners(Rect rect) => [
  rect.topLeft + const Offset(4, 4),
  rect.topRight + const Offset(-4, 4),
  rect.bottomLeft + const Offset(4, -4),
  rect.bottomRight + const Offset(-4, -4),
];

Future<_SingleEventRepository> _pumpPanel(
  WidgetTester tester, {
  required CalendarEvent event,
  CalendarEventDropCallback? onEventDropped,
  ValueChanged<bool>? onEventDragStateChanged,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final settingsRepository = SettingsRepository(preferences: preferences);
  final repository = _SingleEventRepository(event);
  final commandService = EventCommandService(
    repository: repository,
    settingsRepository: settingsRepository,
    notificationService: _NoopNotificationService(),
    syncService: _NoopSyncService(),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        eventRepositoryProvider.overrideWithValue(repository),
        eventCommandServiceProvider.overrideWithValue(commandService),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: EventDetailsPanel(
            date: event.startAt,
            events: [event],
            onEventDropped: onEventDropped,
            onEventDragStateChanged: onEventDragStateChanged,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
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
  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> remoteEvents, {
    required RestoredEventResolver resolve,
  }) async => const [];

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

class _NoopNotificationService implements NotificationService {
  @override
  Future<void> cancelEventReminder(
    String eventId, {
    List<int> reminderMinutesBeforeList = const [],
  }) async {}

  @override
  Future<void> cancelMorningBriefing() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<int> pendingNotificationCount() async => 0;

  @override
  Future<String> permissionSummary() async => '';

  @override
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  }) async {}

  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {}

  @override
  Future<void> showTestNotification() async {}
}

class _NoopSyncService implements SyncService {
  @override
  Future<void> queueEventDelete(String eventId) async {}

  @override
  Future<void> queueEventUpsert(CalendarEvent event) async {}

  @override
  Future<void> queueSettingsBackup() async {}

  @override
  Future<void> start() async {}
}
