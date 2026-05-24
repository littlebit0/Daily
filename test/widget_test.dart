import 'package:daily/app/daily_app.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Daily opens to the weekly calendar shell', (tester) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsNothing);
    expect(find.text('일정 없음'), findsWidgets);
    expect(find.text('일정을 입력하세요'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('swiping the monthly calendar moves to the next month', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'defaultCalendarView': 'month',
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DailyApp)),
    );
    final startMonth = container.read(visibleMonthProvider);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(
      container.read(visibleMonthProvider),
      DateTime(startMonth.year, startMonth.month + 1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _FakeGoogleDriveAuthService extends GoogleDriveAuthService {
  @override
  GoogleDriveAccount? get currentAccount =>
      const GoogleDriveAccount(email: 'tester@example.com');

  @override
  Future<void> initialize() async {}

  @override
  Future<Map<String, String>?> authorizationHeaders({
    bool promptIfNecessary = false,
  }) async {
    return const {'Authorization': 'Bearer test-token'};
  }
}

class _FakeNotification implements NotificationService {
  @override
  Future<void> cancelMorningBriefing() async {}

  @override
  Future<void> cancelEventReminder(String eventId) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleEventReminder(CalendarEvent event) async {}

  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {}
}

class _FakeSync implements SyncService {
  @override
  Future<void> queueEventDelete(String eventId) async {}

  @override
  Future<void> queueEventUpsert(CalendarEvent event) async {}

  @override
  Future<void> start() async {}
}

class _FakeEventRepository implements EventRepository {
  @override
  Future<void> delete(String eventId) async {}

  @override
  Future<void> save(CalendarEvent event) async {}

  @override
  Future<List<CalendarEvent>> search(String query) async => const [];

  @override
  Future<CalendarEvent?> findById(String id) async => null;

  @override
  Future<List<CalendarEvent>> pendingSyncEvents() async => const [];

  @override
  Future<List<CalendarEvent>> allEventsForSync() async => const [];

  @override
  Future<void> markSynced(String eventId) async {}

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    return Stream.value(const []);
  }

  @override
  Future<void> hardDelete(String eventId) async {}

  @override
  Future<void> clearAll() async {}
}
