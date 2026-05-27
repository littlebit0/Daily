import 'package:daily/app/daily_app.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/sync/google_drive_sync_service.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'settings reset ignores missing keychain entitlement during cleanup',
    () async {
      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': true,
        'defaultReminderMinutes': 10,
      });
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(
        preferences: preferences,
        secureStorage: const _MissingEntitlementSecureStorage(),
      );

      await settingsRepository.resetAll();

      expect(settingsRepository.load().onboardingCompleted, isFalse);
      expect(settingsRepository.load().defaultReminderMinutes, 60);
    },
  );

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

  testWidgets('local data reset does not require Google account deletion', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final authService = _FakeGoogleDriveAuthService(account: null);
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: authService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('로컬 데이터 초기화'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('초기화'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Daily 시작하기'), findsOneWidget);
    expect(driveSyncService.deleteCloudBackupCalls, 0);
    expect(authService.signOutCalls, 0);
    expect(eventRepository.clearAllCalls, 1);
    expect(notificationService.cancelMorningBriefingCalls, 1);
    expect(settingsRepository.load().onboardingCompleted, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Google logout can keep using local mode without syncing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final authService = _FakeGoogleDriveAuthService();
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: authService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();

    expect(find.text('로그아웃 방식 선택'), findsOneWidget);
    expect(authService.signOutCalls, 0);

    await tester.tap(find.text('로컬로 전환'));
    await tester.pumpAndSettle();

    expect(authService.signOutCalls, 1);
    expect(driveSyncService.syncNowCalls, 0);
    expect(settingsRepository.load().onboardingCompleted, isTrue);
    expect(find.text('로컬 모드 사용 중'), findsOneWidget);
    expect(find.textContaining('로컬 일정은 그대로 유지됩니다'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Google logout can sync once and return to the start screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final authService = _FakeGoogleDriveAuthService();
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: authService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();

    expect(find.text('로그아웃 방식 선택'), findsOneWidget);
    expect(authService.signOutCalls, 0);
    expect(driveSyncService.syncNowCalls, 0);

    await tester.tap(find.text('동기화 후 시작 화면'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(authService.signOutCalls, 1);
    expect(driveSyncService.syncNowCalls, 1);
    expect(settingsRepository.load().onboardingCompleted, isFalse);
    expect(find.text('Daily 시작하기'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _FakeGoogleDriveAuthService extends GoogleDriveAuthService {
  _FakeGoogleDriveAuthService({
    this.account = const GoogleDriveAccount(email: 'tester@example.com'),
  });

  final GoogleDriveAccount? account;
  var signOutCalls = 0;

  @override
  GoogleDriveAccount? get currentAccount => account;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }

  @override
  Future<Map<String, String>?> authorizationHeaders({
    bool promptIfNecessary = false,
  }) async {
    if (account == null) {
      return null;
    }
    return const {'Authorization': 'Bearer test-token'};
  }
}

class _FakeGoogleDriveSyncService extends GoogleDriveSyncService {
  _FakeGoogleDriveSyncService({
    required super.authService,
    required super.eventRepository,
    required super.notificationService,
    required super.settingsRepository,
  });

  var deleteCloudBackupCalls = 0;
  var syncNowCalls = 0;

  @override
  Future<void> syncNow({bool promptIfNecessary = false}) async {
    syncNowCalls += 1;
  }

  @override
  Future<void> deleteCloudBackup({bool promptIfNecessary = false}) async {
    deleteCloudBackupCalls += 1;
  }
}

class _FakeNotification implements NotificationService {
  var cancelMorningBriefingCalls = 0;

  @override
  Future<void> cancelMorningBriefing() async {
    cancelMorningBriefingCalls += 1;
  }

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
  var clearAllCalls = 0;

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
  Future<void> clearAll() async {
    clearAllCalls += 1;
  }
}

class _MissingEntitlementSecureStorage extends FlutterSecureStorage {
  const _MissingEntitlementSecureStorage();

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    throw PlatformException(
      code: 'Unexpected security result code',
      message: "A required entitlement isn't present.",
      details: -34018,
    );
  }
}
