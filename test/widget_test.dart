import 'dart:async';

import 'package:daily/app/daily_app.dart';
import 'package:daily/app/daily_theme.dart';
import 'package:daily/core/auth/apple_sign_in_service.dart';
import 'package:daily/core/auth/apple_account.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/analytics/product_analytics.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/sync/google_drive_sync_service.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/events/presentation/event_details_panel.dart';
import 'package:daily/features/events/presentation/event_editor_dialog.dart';
import 'package:daily/features/calendar/widgets/calendar_month_grid.dart';
import 'package:daily/features/calendar/presentation/month_calendar_page.dart';
import 'package:daily/features/settings/presentation/settings_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openWelcomeStartPage(WidgetTester tester) async {
  if (find.text('건너뛰기').evaluate().isEmpty) {
    return;
  }
  await tester.tap(find.text('건너뛰기'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.localesTestValue =
        const [Locale('ko')];
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearLocalesTestValue();
  });

  test('quick Todo columns stay two on iOS and respond to macOS width', () {
    expect(quickTodoColumnCountForPlatform(TargetPlatform.iOS, 320), 2);
    expect(quickTodoColumnCountForPlatform(TargetPlatform.iOS, 1024), 2);
    expect(quickTodoColumnCountForPlatform(TargetPlatform.macOS, 560), 1);
    expect(quickTodoColumnCountForPlatform(TargetPlatform.macOS, 700), 2);
    expect(quickTodoColumnCountForPlatform(TargetPlatform.macOS, 1000), 3);
  });

  test(
    'macOS and Windows use desktop text scales instead of iPhone scales',
    () {
      expect(
        appTextScaleForPlatform(AppTextSize.basic, TargetPlatform.macOS),
        1.0,
      );
      expect(
        appTextScaleForPlatform(AppTextSize.large, TargetPlatform.macOS),
        1.15,
      );
      expect(
        appTextScaleForPlatform(AppTextSize.extraLarge, TargetPlatform.macOS),
        1.3,
      );
      expect(
        appTextScaleForPlatform(AppTextSize.basic, TargetPlatform.windows),
        1.0,
      );
      expect(
        appTextScaleForPlatform(AppTextSize.large, TargetPlatform.windows),
        1.15,
      );
      expect(
        appTextScaleForPlatform(AppTextSize.extraLarge, TargetPlatform.windows),
        1.3,
      );
      expect(
        appTextScaleForPlatform(AppTextSize.basic, TargetPlatform.iOS),
        0.8,
      );
      expect(
        appTextScaleForPlatform(AppTextSize.extraLarge, TargetPlatform.iOS),
        1.15,
      );
    },
  );

  test('Android and Windows expose the adjacent-month date setting', () {
    expect(supportsAdjacentMonthDateSetting(TargetPlatform.android), isTrue);
    expect(supportsAdjacentMonthDateSetting(TargetPlatform.windows), isTrue);
    expect(supportsAdjacentMonthDateSetting(TargetPlatform.linux), isFalse);
  });

  test('theme mode remains selected after settings reload', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);

    await repository.save(
      repository.load().copyWith(themeMode: AppThemeMode.dark),
    );

    expect(repository.load().themeMode, AppThemeMode.dark);
    expect(DailyTheme.dark().brightness, Brightness.dark);
    expect(DailyTheme.light().brightness, Brightness.light);
    final darkTheme = DailyTheme.dark();
    expect(darkTheme.scaffoldBackgroundColor, const Color(0xff000000));
    expect(
      darkTheme.colorScheme.surfaceContainerLowest,
      const Color(0xff000000),
    );
    expect(darkTheme.colorScheme.surface, const Color(0xff0a0b0d));
    expect(darkTheme.colorScheme.surfaceContainerHigh, const Color(0xff11141a));
  });

  test(
    'month navigation mode remains selected after settings reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: preferences);

      await repository.save(
        repository.load().copyWith(
          monthNavigationMode: MonthNavigationMode.vertical,
        ),
      );

      expect(
        repository.load().monthNavigationMode,
        MonthNavigationMode.vertical,
      );
    },
  );

  test(
    'week and day layout mode remains selected after settings reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: preferences);

      await repository.save(
        repository.load().copyWith(
          weekDayLayoutMode: WeekDayLayoutMode.schedule,
        ),
      );

      expect(repository.load().weekDayLayoutMode, WeekDayLayoutMode.schedule);
    },
  );

  testWidgets(
    'schedule view scrolls time vertically and changes week horizontally',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': true,
        'defaultCalendarView': 'week',
        'weekDayLayoutMode': 'schedule',
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

      expect(find.byKey(const ValueKey('schedule-timeline')), findsWidgets);
      expect(
        find.byKey(const ValueKey('schedule-all-day-toggle')),
        findsWidgets,
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DailyApp)),
      );
      final initialDate = container.read(selectedDateProvider);
      final timeScroll = find
          .byKey(const ValueKey('schedule-time-scroll'))
          .first;
      final scrollable = tester.widget<SingleChildScrollView>(timeScroll);
      final initialOffset = scrollable.controller!.offset;
      await tester.drag(timeScroll, const Offset(0, -180));
      await tester.pumpAndSettle();

      expect(scrollable.controller!.offset, greaterThan(initialOffset));
      expect(container.read(selectedDateProvider), initialDate);

      await tester.tap(
        find.byKey(const ValueKey('schedule-all-day-toggle')).first,
      );
      await tester.pump();
      expect(find.byIcon(Icons.event_busy_outlined), findsWidgets);

      await tester.drag(
        find.byKey(const ValueKey('schedule-timeline')).first,
        const Offset(-280, 0),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(selectedDateProvider).difference(initialDate).inDays,
        7,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'macOS year overview shows two columns and moves to adjacent years',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': true,
        'defaultCalendarView': 'month',
      });
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      await settingsRepository.save(
        settingsRepository.load().copyWith(
          monthNavigationMode: MonthNavigationMode.vertical,
        ),
      );

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
      final verticalMonthList = find.byKey(
        const ValueKey('continuous-month-scroll'),
      );
      final verticalMonthController = tester
          .widget<ListView>(verticalMonthList)
          .controller!;
      final wheelStart = verticalMonthController.offset;
      verticalMonthController.position.pointerScroll(120);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(verticalMonthController.offset, greaterThan(wheelStart));
      expect(verticalMonthController.offset, lessThan(wheelStart + 120));
      await tester.pumpAndSettle();
      expect(verticalMonthController.offset, closeTo(wheelStart + 120, 0.1));

      final year = container.read(visibleMonthProvider).year;
      await tester.tap(find.text('$year년').first);
      await tester.pumpAndSettle();

      expect(find.text('$year-${year + 1}년'), findsNothing);
      expect(find.byKey(ValueKey('mini-month-$year-1')), findsOneWidget);
      expect(find.byKey(ValueKey('mini-month-${year + 1}-1')), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(ValueKey('mini-month-canvas-$year-1')))
            .height,
        greaterThan(100),
      );

      final overview = find.byKey(
        const ValueKey('year-overview-continuous-scroll'),
      );
      await tester.drag(overview, const Offset(0, 620));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('mini-month-${year - 1}-1')), findsOneWidget);
      expect(find.byKey(ValueKey('mini-month-${year - 200}-1')), findsNothing);

      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('iOS year overview moves to the immediately previous year', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'defaultCalendarView': 'month',
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    await settingsRepository.save(
      settingsRepository.load().copyWith(
        monthNavigationMode: MonthNavigationMode.vertical,
      ),
    );

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
    final year = container.read(visibleMonthProvider).year;
    await tester.tap(find.text('$year년').first);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('year-overview-continuous-scroll')),
      const Offset(0, 800),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('mini-month-${year - 1}-1')), findsOneWidget);
    expect(find.byKey(ValueKey('mini-month-${year - 200}-1')), findsNothing);

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('Apple platforms automatically request system authentication', () {
    expect(shouldAutomaticallyRequestBiometrics(TargetPlatform.macOS), isTrue);
    expect(shouldAutomaticallyRequestBiometrics(TargetPlatform.iOS), isTrue);
    expect(
      shouldAutomaticallyRequestBiometrics(
        TargetPlatform.android,
        alreadyAttempted: true,
      ),
      isFalse,
    );
  });

  test('app text size remains selected after settings reload', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await settingsRepository.save(
      settingsRepository.load().copyWith(appTextSize: AppTextSize.extraLarge),
    );

    expect(settingsRepository.load().appTextSize, AppTextSize.extraLarge);
  });

  test(
    'adjacent-month date visibility remains selected after reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);

      await settingsRepository.save(
        settingsRepository.load().copyWith(showAdjacentMonthDates: false),
      );

      expect(settingsRepository.load().showAdjacentMonthDates, isFalse);
    },
  );

  test('legacy default reminder migrates into the reminder list', () async {
    SharedPreferences.setMockInitialValues({'defaultReminderMinutes': 10});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    expect(settingsRepository.load().defaultReminderMinutesList, [10]);
  });

  test('multiple default reminders remain selected after reload', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await settingsRepository.save(
      settingsRepository.load().copyWith(
        defaultReminderMinutesList: const [60, 10, 30, 10],
      ),
    );

    expect(settingsRepository.load().defaultReminderMinutesList, [10, 30, 60]);
  });

  test('empty default reminder list remains disabled after reload', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await settingsRepository.save(
      settingsRepository.load().copyWith(
        defaultReminderMinutesList: const <int>[],
      ),
    );

    expect(settingsRepository.load().defaultReminderMinutesList, isEmpty);
  });

  test(
    'settings reset ignores missing keychain entitlement during cleanup',
    () async {
      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': true,
        'defaultReminderMinutes': 10,
        'appleUserIdentifier': 'apple-user',
        'appleEmail': 'apple@example.com',
      });
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(
        preferences: preferences,
        secureStorage: const _MissingEntitlementSecureStorage(),
      );

      await settingsRepository.resetAll();

      expect(settingsRepository.load().onboardingCompleted, isFalse);
      expect(settingsRepository.load().defaultReminderMinutes, 60);
      expect(settingsRepository.appleAccount(), isNull);
    },
  );

  test(
    'Google Drive desktop session survives auth service recreation',
    () async {
      final storage = _MemorySecureStorage();
      await storage.write(
        key: 'daily.google_drive.access_token',
        value: 'access-token',
      );
      await storage.write(
        key: 'daily.google_drive.refresh_token',
        value: 'refresh-token',
      );
      await storage.write(
        key: 'daily.google_drive.expires_at',
        value: DateTime.now()
            .toUtc()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      );
      await storage.write(
        key: 'daily.google_drive.email',
        value: 'persisted@example.com',
      );
      await storage.write(
        key: 'daily.google_drive.display_name',
        value: 'Persisted User',
      );

      final firstService = GoogleDriveAuthService(
        secureStorage: storage,
        useDesktopOAuth: true,
      );
      final secondService = GoogleDriveAuthService(
        secureStorage: storage,
        useDesktopOAuth: true,
      );

      expect(
        (await firstService.restorePreviousSignIn())?.email,
        'persisted@example.com',
      );
      expect(
        (await secondService.restorePreviousSignIn())?.email,
        'persisted@example.com',
      );
      expect(await secondService.authorizationHeaders(), {
        'Authorization': 'Bearer access-token',
      });
    },
  );

  test('Google Drive restore reports a missing keychain entitlement', () async {
    final service = GoogleDriveAuthService(
      secureStorage: const _MissingEntitlementSecureStorage(),
      useDesktopOAuth: true,
    );

    await expectLater(
      service.restorePreviousSignIn(),
      throwsA(isA<GoogleDriveAuthException>()),
    );
  });

  test(
    'app lock stores the configured PIN length with its secure hash',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final secureStorage = _MemorySecureStorage();
      final settingsRepository = SettingsRepository(
        preferences: preferences,
        secureStorage: secureStorage,
      );

      await settingsRepository.saveAppLockPin('13579');

      expect(await settingsRepository.appLockPinLength(), 5);
      expect(await settingsRepository.verifyAppLockPin('13579'), isTrue);
      expect(await settingsRepository.verifyAppLockPin('1357'), isFalse);

      await settingsRepository.deleteAppLockPin();

      expect(await settingsRepository.appLockPinLength(), isNull);
      expect(await settingsRepository.verifyAppLockPin('13579'), isFalse);
    },
  );

  test('legacy biometric app lock migrates to the system method', () async {
    SharedPreferences.setMockInitialValues({
      'appLockEnabled': true,
      'appLockBiometricsEnabled': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final settings = SettingsRepository(preferences: preferences).load();

    expect(settings.appLockMethod, AppLockMethod.system);
  });

  test('selected app lock method remains stored locally', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);

    await repository.save(
      repository.load().copyWith(
        appLockEnabled: true,
        appLockMethod: AppLockMethod.noPin,
      ),
    );

    expect(repository.load().appLockMethod, AppLockMethod.noPin);
  });

  test(
    'Apple account refresh keeps saved app login marker if revoked',
    () async {
      SharedPreferences.setMockInitialValues({
        'appleUserIdentifier': 'apple-user',
        'appleEmail': 'hwi@example.com',
      });
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      final appleSignInService = AppleSignInService(
        settingsRepository: settingsRepository,
        targetPlatform: TargetPlatform.iOS,
        availabilityChecker: () async => true,
        credentialStateChecker: (_) async => CredentialState.revoked,
      );

      final account = await appleSignInService.refreshCurrentAccount();

      expect(account?.email, 'hwi@example.com');
      expect(settingsRepository.appleAccount()?.email, 'hwi@example.com');
    },
  );

  test('Apple unknown auth error explains sideloaded IPA limitation', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final appleSignInService = AppleSignInService(
      settingsRepository: settingsRepository,
      targetPlatform: TargetPlatform.iOS,
      availabilityChecker: () async => true,
      credentialRequester: ({required scopes}) async {
        throw const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.unknown,
          message: 'unknown',
        );
      },
    );

    await expectLater(
      appleSignInService.signIn(),
      throwsA(
        isA<AppleSignInException>().having(
          (error) => error.message,
          'message',
          allOf(contains('SideStore'), contains('Google로 계속')),
        ),
      ),
    );
  });

  test('Daily account keeps Apple and Google identities together', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);

    await settingsRepository.saveAppleAccount(
      const AppleAccount(
        userIdentifier: 'apple-user',
        email: 'apple@example.com',
      ),
    );
    final accountAfterApple = settingsRepository.dailyAccount();
    await settingsRepository.saveGoogleAccount(
      const GoogleAccount(email: 'google@example.com', displayName: 'Daily'),
    );
    final mergedAccount = settingsRepository.dailyAccount();

    expect(mergedAccount?.id, accountAfterApple?.id);
    expect(mergedAccount?.appleAccount?.userIdentifier, 'apple-user');
    expect(mergedAccount?.googleAccount?.email, 'google@example.com');
  });

  test(
    'Daily account reset removes merged Apple and Google identities',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      await settingsRepository.saveAppleAccount(
        const AppleAccount(userIdentifier: 'apple-user'),
      );
      await settingsRepository.saveGoogleAccount(
        const GoogleAccount(email: 'google@example.com'),
      );

      await settingsRepository.resetAll();

      expect(settingsRepository.dailyAccount(), isNull);
      expect(settingsRepository.appleAccount(), isNull);
    },
  );

  testWidgets('Apple sign-in restores an already linked Google session', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    await settingsRepository.saveAppleAccount(
      const AppleAccount(
        userIdentifier: 'apple-user',
        email: 'hwi@example.com',
      ),
    );
    await settingsRepository.saveGoogleAccount(
      const GoogleAccount(email: 'linked@example.com'),
    );
    final appleSignInService = AppleSignInService(
      settingsRepository: settingsRepository,
      targetPlatform: TargetPlatform.iOS,
      availabilityChecker: () async => true,
      credentialRequester: ({required scopes}) async {
        expect(scopes, contains(AppleIDAuthorizationScopes.email));
        expect(scopes, contains(AppleIDAuthorizationScopes.fullName));
        return const AuthorizationCredentialAppleID(
          userIdentifier: 'apple-user',
          givenName: 'Hwi',
          familyName: 'Kim',
          authorizationCode: 'auth-code',
          email: 'hwi@example.com',
          identityToken: 'identity-token',
          state: null,
        );
      },
    );
    final googleAuthService = _FakeGoogleDriveAuthService(
      account: null,
      restoredAccount: const GoogleDriveAccount(email: 'linked@example.com'),
    );
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: googleAuthService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(googleAuthService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
          appleSignInServiceProvider.overrideWithValue(appleSignInService),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _openWelcomeStartPage(tester);

    expect(find.text('Apple로 계속'), findsOneWidget);

    await tester.tap(find.text('Apple로 계속'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(settingsRepository.load().onboardingCompleted, isTrue);
    expect(settingsRepository.appleAccount()?.email, 'hwi@example.com');
    expect(
      googleAuthService.restorePreviousSignInCalls,
      greaterThanOrEqualTo(1),
    );
    expect(googleAuthService.signInCalls, 0);
    expect(driveSyncService.startListeningOnlyCalls, greaterThanOrEqualTo(1));
    expect(
      driveSyncService.syncPendingChangesNowCalls,
      greaterThanOrEqualTo(1),
    );
    expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Apple sign-in starts Daily without opening Google login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final appleSignInService = AppleSignInService(
      settingsRepository: settingsRepository,
      targetPlatform: TargetPlatform.iOS,
      availabilityChecker: () async => true,
      credentialRequester: ({required scopes}) async {
        return const AuthorizationCredentialAppleID(
          userIdentifier: 'apple-user',
          givenName: 'Hwi',
          familyName: 'Kim',
          authorizationCode: 'auth-code',
          email: 'hwi@example.com',
          identityToken: 'identity-token',
          state: null,
        );
      },
    );
    final googleAuthService = _FakeGoogleDriveAuthService(
      account: null,
      signInAccount: const GoogleDriveAccount(email: 'linked@example.com'),
    );
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final driveSyncService = _FakeGoogleDriveSyncService(
      authService: googleAuthService,
      eventRepository: eventRepository,
      notificationService: notificationService,
      settingsRepository: settingsRepository,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(googleAuthService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
          appleSignInServiceProvider.overrideWithValue(appleSignInService),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _openWelcomeStartPage(tester);

    await tester.tap(find.text('Apple로 계속'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(settingsRepository.appleAccount()?.email, 'hwi@example.com');
    expect(settingsRepository.load().onboardingCompleted, isTrue);
    // App startup may make a silent restoration attempt, but Apple sign-in
    // itself must never open the interactive Google authentication flow.
    expect(
      googleAuthService.restorePreviousSignInCalls,
      greaterThanOrEqualTo(1),
    );
    expect(googleAuthService.signInCalls, 0);
    expect(driveSyncService.syncPendingChangesNowCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Google sign-in preserves the linked Apple identity', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    await settingsRepository.saveAppleAccount(
      const AppleAccount(
        userIdentifier: 'linked-apple-user',
        email: 'apple@example.com',
      ),
    );
    final authService = _FakeGoogleDriveAuthService(
      account: null,
      signInAccount: const GoogleDriveAccount(
        email: 'google@example.com',
        displayName: 'Google User',
      ),
    );
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
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _openWelcomeStartPage(tester);

    await tester.tap(find.text('Google로 계속'));
    await tester.pumpAndSettle();

    final mergedAccount = settingsRepository.dailyAccount();
    expect(mergedAccount?.appleAccount?.userIdentifier, 'linked-apple-user');
    expect(mergedAccount?.googleAccount?.email, 'google@example.com');
    expect(settingsRepository.load().onboardingCompleted, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'welcome keeps desktop Google auth active until the user cancels it',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      final authService = _FakeGoogleDriveAuthService(
        account: null,
        signInCompleter: Completer<GoogleDriveAccount?>(),
        canCancelOnResume: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(_FakeNotification()),
            syncServiceProvider.overrideWithValue(_FakeSync()),
            eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
            googleDriveAuthServiceProvider.overrideWithValue(authService),
          ],
          child: const DailyApp(),
        ),
      );
      await tester.pumpAndSettle();
      await _openWelcomeStartPage(tester);

      await tester.tap(find.text('Google로 계속'));
      await tester.pump();

      expect(authService.signInCalls, 1);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Google 연결 중'),
            )
            .onPressed,
        isNull,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(authService.cancelPendingSignInCalls, 0);
      expect(find.text('연결 취소'), findsOneWidget);
      await tester.tap(find.text('연결 취소'));
      await tester.pump();

      expect(authService.cancelPendingSignInCalls, 1);
      expect(
        find.text('Google Drive 연결이 취소되었습니다. 다시 연결할 수 있습니다.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Google로 계속'),
            )
            .onPressed,
        isNotNull,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Daily opens to the weekly calendar shell and swipes weeks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'appleUserIdentifier': 'apple-user',
      'appleEmail': 'hwi@example.com',
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

    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-switcher'))).width,
      124,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-switcher'))).height,
      40,
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('bottom-mode-switcher'))).dx,
      closeTo(
        tester.getCenter(find.byKey(const ValueKey('calendar-bottom-bar'))).dx,
        0.1,
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('calendar-view-button'))).width,
      lessThan(96),
    );
    final compactViewButtonSize = tester.getSize(
      find.byKey(const ValueKey('calendar-view-button')),
    );
    final compactViewThumbSize = tester.getSize(
      find.byKey(const ValueKey('calendar-view-thumb-circle')),
    );
    expect(compactViewButtonSize, const Size(76, 40));
    expect(compactViewThumbSize, const Size.square(32));
    expect(
      tester
          .widget<AnimatedContainer>(
            find.byKey(const ValueKey('calendar-view-track')),
          )
          .clipBehavior,
      Clip.none,
    );
    expect(
      tester
          .widget<Container>(find.byKey(const ValueKey('bottom-mode-track')))
          .clipBehavior,
      Clip.none,
    );
    expect(
      tester
          .widget<Stack>(
            find.byKey(const ValueKey('calendar-view-thumb-layer')),
          )
          .clipBehavior,
      Clip.none,
    );
    expect(
      tester
          .widget<Stack>(find.byKey(const ValueKey('bottom-mode-thumb-layer')))
          .clipBehavior,
      Clip.none,
    );
    expect(
      compactViewThumbSize.width,
      closeTo(compactViewThumbSize.height, 0.6),
    );
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('일정 없음'), findsWidgets);
    expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
    expect(find.byTooltip('오늘'), findsOneWidget);
    final periodButtonRect = tester.getRect(
      find.byKey(const ValueKey('calendar-period-button')),
    );
    final reservedSpaceRect = tester.getRect(
      find.byKey(const ValueKey('ios-calendar-header-reserved-space')),
    );
    expect(periodButtonRect.width, lessThan(180));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('calendar-period-button')),
        matching: find.byType(FittedBox),
      ),
      findsOneWidget,
    );
    expect(periodButtonRect.left, lessThan(16));
    expect(reservedSpaceRect.left, closeTo(periodButtonRect.right, 0.1));
    expect(reservedSpaceRect.width, greaterThan(0));

    final compactViewButtonRect = tester.getRect(
      find.byKey(const ValueKey('calendar-view-button')),
    );
    await tester.tapAt(
      Offset(
        compactViewButtonRect.left + compactViewButtonRect.width / 6,
        compactViewButtonRect.center.dy,
      ),
    );
    await tester.pumpAndSettle();
    final expandedViewButtonSize = tester.getSize(
      find.byKey(const ValueKey('calendar-view-button')),
    );
    expect(expandedViewButtonSize.width, greaterThan(76));
    expect(expandedViewButtonSize.height, greaterThan(40));
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-switcher'))),
      const Size(124, 40),
    );

    final expandedViewButtonRect = tester.getRect(
      find.byKey(const ValueKey('calendar-view-button')),
    );
    await tester.tapAt(
      Offset(
        expandedViewButtonRect.left + expandedViewButtonRect.width / 6,
        expandedViewButtonRect.center.dy,
      ),
    );
    await tester.pump(const Duration(milliseconds: 90));

    expect(
      tester.getSize(find.byKey(const ValueKey('calendar-view-button'))),
      expandedViewButtonSize,
    );
    await tester.pumpAndSettle();

    final iosToolbarBeforeQuickAccess = tester.getRect(
      find.byKey(const ValueKey('ios-calendar-toolbar')),
    );
    await tester.drag(
      find.byKey(const ValueKey('bottom-mode-switcher')),
      const Offset(-70, 0),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      tester.getRect(find.byKey(const ValueKey('ios-calendar-toolbar'))),
      iosToolbarBeforeQuickAccess,
    );
    await tester.pumpAndSettle();

    expect(find.text('빠른 보기'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byKey(const ValueKey('bottom-mode-thumb')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-thumb-circle'))),
      const Size.square(40),
    );
    expect(find.byKey(const ValueKey('calendar-view-button')), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-switcher'))).width,
      152,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-switcher'))).height,
      48,
    );
    final quickAccessIcon = find.descendant(
      of: find.byKey(const ValueKey('bottom-mode-switcher')),
      matching: find.byIcon(Icons.dashboard_outlined),
    );
    expect(
      tester
          .getCenter(find.byKey(const ValueKey('bottom-mode-thumb-circle')))
          .dx,
      closeTo(tester.getCenter(quickAccessIcon).dx, 0.5),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('bottom-mode-switcher'))).dx,
      closeTo(
        tester.getCenter(find.byKey(const ValueKey('calendar-bottom-bar'))).dx,
        0.1,
      ),
    );

    await tester.tap(quickAccessIcon);
    await tester.pump(const Duration(milliseconds: 90));

    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-switcher'))),
      const Size(152, 48),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('달력'));
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-view-button')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const ValueKey('calendar-view-button'))).right,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('bottom-mode-switcher'))).left,
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DailyApp)),
    );
    final startDate = container.read(selectedDateProvider);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('bottom-mode-thumb')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-thumb-circle'))),
      const Size.square(32),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-switcher'))).width,
      124,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-mode-switcher'))).height,
      40,
    );
    expect(
      container.read(selectedDateProvider),
      DateTime(startDate.year, startDate.month, startDate.day + 7),
    );

    final iosToolbarBeforeAi = tester.getRect(
      find.byKey(const ValueKey('ios-calendar-toolbar')),
    );
    final calendarHeightBeforeAi = tester.getSize(find.byType(PageView)).height;

    await tester.tap(find.byTooltip('AI'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('inline-ai-layout-panel')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('inline-ai-input')), findsOneWidget);
    expect(find.byKey(const ValueKey('inline-ai-panel')), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('inline-ai-layout-panel')))
          .height,
      greaterThan(0),
    );
    expect(
      tester.getSize(find.byType(PageView)).height,
      lessThan(calendarHeightBeforeAi),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('ios-calendar-toolbar'))),
      iosToolbarBeforeAi,
    );
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byTooltip('AI 입력 닫기'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('iOS calendar view slider expands for English labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'appleUserIdentifier': 'apple-user',
      'appleEmail': 'hwi@example.com',
      'language': AppLanguage.english.name,
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

    final viewSlider = find.byKey(const ValueKey('calendar-view-button'));
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);
    expect(tester.getSize(viewSlider).width, greaterThan(76));
    expect(
      tester.getRect(viewSlider).right,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('bottom-mode-switcher'))).left,
      ),
    );

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Signal typed event changes require explicit confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    const signalChannel = MethodChannel('daily/signal_voice');
    final signalCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(signalChannel, (call) async {
          signalCalls.add(call);
          return switch (call.method) {
            'startListening' => throw PlatformException(
              code: 'listening_cancelled',
            ),
            'cancelListening' || 'speak' => null,
            'runSignal'
                when (call.arguments as Map<Object?, Object?>)['confirmed'] ==
                    false =>
              throw PlatformException(code: 'signal_confirmation_required'),
            'runSignal' => <String, Object?>{
              'message': '일정을 추가했습니다.',
              'success': true,
            },
            _ => throw PlatformException(code: 'unexpected_method'),
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(signalChannel, null);
    });

    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'appleUserIdentifier': 'apple-user',
      'appleEmail': 'hwi@example.com',
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

    await tester.tap(find.byTooltip('AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('텍스트로 입력'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('signal-text-input')),
      '내일 오전 9시부터 10시까지 운동 일정 추가',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('이 명령을 실행할까요?'), findsOneWidget);
    final previewCall = signalCalls.singleWhere(
      (call) => call.method == 'runSignal',
    );
    expect(previewCall.arguments, {
      'command': '내일 오전 9시부터 10시까지 운동 일정 추가',
      'confirmed': false,
    });

    await tester.tap(find.widgetWithText(FilledButton, '실행'));
    await tester.pumpAndSettle();

    final runCall = signalCalls
        .where((call) => call.method == 'runSignal')
        .last;
    expect(runCall.arguments, {
      'command': '내일 오전 9시부터 10시까지 운동 일정 추가',
      'confirmed': true,
    });
    expect(find.text('일정을 추가했습니다.'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('macOS uses its header toolbar without the iOS bottom bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
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

    expect(
      find.byKey(const ValueKey('macos-calendar-toolbar')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('macos-calendar-toolbar')))
          .height,
      lessThan(64),
    );
    expect(find.byKey(const ValueKey('calendar-bottom-bar')), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DailyApp)),
    );
    final startDate = container.read(selectedDateProvider);
    final weekPageView = tester.widget<PageView>(find.byType(PageView));
    expect(weekPageView.physics, isA<PageScrollPhysics>());
    final weekController = weekPageView.controller!;

    await tester.tap(find.byTooltip('이전'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(weekController.page, greaterThan(11999));
    expect(weekController.page, lessThan(12000));

    await tester.pumpAndSettle();
    expect(
      container.read(selectedDateProvider),
      DateTime(startDate.year, startDate.month, startDate.day - 7),
    );

    final weekNavigation = find.byKey(
      const ValueKey('week-pointer-navigation'),
    );
    final weekListener = tester.widget<Listener>(weekNavigation);
    weekListener.onPointerSignal!(
      const PointerScrollEvent(
        kind: PointerDeviceKind.trackpad,
        scrollDelta: Offset(30, 0),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), startDate);

    weekListener.onPointerSignal!(
      const PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        scrollDelta: Offset(0, 30),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(selectedDateProvider),
      DateTime(startDate.year, startDate.month, startDate.day + 7),
    );

    await tester.tap(find.byTooltip('이전'));
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), startDate);

    await tester.trackpadFling(
      weekNavigation,
      const Offset(-240, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(
      container.read(selectedDateProvider),
      DateTime(startDate.year, startDate.month, startDate.day + 7),
    );
    await tester.trackpadFling(
      weekNavigation,
      const Offset(240, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), startDate);

    container.read(appSettingsProvider.notifier).state = container
        .read(appSettingsProvider)
        .copyWith(weekDayLayoutMode: WeekDayLayoutMode.schedule);
    await tester.pumpAndSettle();
    final scheduleWeekNavigation = find.byKey(
      const ValueKey('week-pointer-navigation'),
    );
    await tester.trackpadFling(
      scheduleWeekNavigation,
      const Offset(-240, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(
      container.read(selectedDateProvider),
      DateTime(startDate.year, startDate.month, startDate.day + 7),
    );
    await tester.trackpadFling(
      scheduleWeekNavigation,
      const Offset(240, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), startDate);
    container.read(appSettingsProvider.notifier).state = container
        .read(appSettingsProvider)
        .copyWith(weekDayLayoutMode: WeekDayLayoutMode.list);
    await tester.pumpAndSettle();

    final macToolbarBeforeTransition = tester.getRect(
      find.byKey(const ValueKey('macos-calendar-toolbar')),
    );
    container.read(calendarViewModeProvider.notifier).state =
        CalendarViewMode.day;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      tester.getRect(find.byKey(const ValueKey('macos-calendar-toolbar'))),
      macToolbarBeforeTransition,
    );
    final viewTransitions = tester
        .widgetList<SlideTransition>(
          find.descendant(
            of: find.byKey(const ValueKey('calendar-content-switcher')),
            matching: find.byType(SlideTransition),
          ),
        )
        .where((transition) => transition.child?.key is ValueKey<int>)
        .toList();
    expect(
      viewTransitions
          .singleWhere(
            (transition) => transition.child?.key == const ValueKey<int>(3),
          )
          .position
          .value
          .dx,
      greaterThan(0),
    );
    expect(
      viewTransitions
          .singleWhere(
            (transition) => transition.child?.key == const ValueKey<int>(1),
          )
          .position
          .value
          .dx,
      lessThan(0),
    );
    await tester.pumpAndSettle();
    final dayListener = tester.widget<Listener>(
      find.byKey(const ValueKey('day-pointer-navigation')),
    );
    expect(
      tester.widget<PageView>(find.byType(PageView)).physics,
      isA<PageScrollPhysics>(),
    );
    dayListener.onPointerSignal!(
      const PointerScrollEvent(
        kind: PointerDeviceKind.trackpad,
        scrollDelta: Offset(30, 0),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(selectedDateProvider),
      DateTime(startDate.year, startDate.month, startDate.day + 1),
    );

    dayListener.onPointerSignal!(
      const PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        scrollDelta: Offset(0, 30),
      ),
    );
    await tester.pumpAndSettle();
    final listDateAfterVerticalWheel = DateTime(
      startDate.year,
      startDate.month,
      startDate.day + 2,
    );
    expect(container.read(selectedDateProvider), listDateAfterVerticalWheel);
    await tester.trackpadFling(
      find.byKey(const ValueKey('day-pointer-navigation')),
      const Offset(-240, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(
      container.read(selectedDateProvider),
      DateTime(startDate.year, startDate.month, startDate.day + 3),
    );
    await tester.trackpadFling(
      find.byKey(const ValueKey('day-pointer-navigation')),
      const Offset(240, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), listDateAfterVerticalWheel);

    container.read(appSettingsProvider.notifier).state = container
        .read(appSettingsProvider)
        .copyWith(weekDayLayoutMode: WeekDayLayoutMode.schedule);
    await tester.pumpAndSettle();
    final scheduleDayNavigation = find.byKey(
      const ValueKey('day-pointer-navigation'),
    );
    await tester.trackpadFling(
      scheduleDayNavigation,
      const Offset(-240, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(
      container.read(selectedDateProvider),
      DateTime(startDate.year, startDate.month, startDate.day + 3),
    );
    await tester.trackpadFling(
      scheduleDayNavigation,
      const Offset(240, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), listDateAfterVerticalWheel);
    final scheduleDayListener = tester.widget<Listener>(
      find.byKey(const ValueKey('day-pointer-navigation')),
    );
    scheduleDayListener.onPointerSignal!(
      const PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        scrollDelta: Offset(0, 30),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), listDateAfterVerticalWheel);

    final scheduleTimeScroll = find
        .byKey(const ValueKey('schedule-time-scroll'))
        .first;
    final scheduleScrollable = tester.widget<SingleChildScrollView>(
      scheduleTimeScroll,
    );
    final scheduleOffsetBeforeWheel = scheduleScrollable.controller!.offset;
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(scheduleTimeScroll),
        scrollDelta: const Offset(0, 120),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), listDateAfterVerticalWheel);
    expect(
      scheduleScrollable.controller!.offset,
      greaterThan(scheduleOffsetBeforeWheel),
    );
    container.read(appSettingsProvider.notifier).state = container
        .read(appSettingsProvider)
        .copyWith(weekDayLayoutMode: WeekDayLayoutMode.list);
    await tester.pumpAndSettle();

    container.read(calendarViewModeProvider.notifier).state =
        CalendarViewMode.month;
    await tester.pumpAndSettle();
    final monthBeforeScroll = container.read(visibleMonthProvider);
    final monthListener = tester.widget<Listener>(
      find.byKey(const ValueKey('month-pointer-navigation')),
    );
    expect(
      tester
          .widget<PageView>(
            find.descendant(
              of: find.byKey(const ValueKey('month-pointer-navigation')),
              matching: find.byType(PageView),
            ),
          )
          .physics,
      isA<PageScrollPhysics>(),
    );
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(
          find.byKey(const ValueKey('month-pointer-navigation')),
        ),
        scrollDelta: const Offset(0, 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(visibleMonthProvider),
      DateTime(monthBeforeScroll.year, monthBeforeScroll.month + 1),
    );

    for (var index = 0; index < 4; index++) {
      monthListener.onPointerSignal!(
        const PointerScrollEvent(
          kind: PointerDeviceKind.mouse,
          scrollDelta: Offset(1, 0),
        ),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pump(const Duration(milliseconds: 260));
    expect(
      container.read(visibleMonthProvider),
      DateTime(monthBeforeScroll.year, monthBeforeScroll.month + 5),
    );
    await tester.pumpAndSettle();
    await tester.trackpadFling(
      find.byKey(const ValueKey('month-pointer-navigation')),
      const Offset(-240, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(
      container.read(visibleMonthProvider),
      DateTime(monthBeforeScroll.year, monthBeforeScroll.month + 6),
    );
    await tester.trackpadFling(
      find.byKey(const ValueKey('month-pointer-navigation')),
      const Offset(240, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(
      container.read(visibleMonthProvider),
      DateTime(monthBeforeScroll.year, monthBeforeScroll.month + 5),
    );

    await tester.tap(find.byTooltip('빠른 보기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final quickAccessTransitions = tester
        .widgetList<SlideTransition>(
          find.descendant(
            of: find.byKey(const ValueKey('calendar-content-switcher')),
            matching: find.byType(SlideTransition),
          ),
        )
        .where((transition) => transition.child?.key is ValueKey<int>)
        .toList();
    expect(
      quickAccessTransitions
          .singleWhere(
            (transition) => transition.child?.key == const ValueKey<int>(0),
          )
          .position
          .value
          .dx,
      lessThan(0),
    );
    expect(
      quickAccessTransitions
          .singleWhere(
            (transition) => transition.child?.key == const ValueKey<int>(2),
          )
          .position
          .value
          .dx,
      greaterThan(0),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsNothing);
    expect(
      find.byKey(const ValueKey('macos-calendar-toolbar')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('calendar-bottom-bar')), findsNothing);

    final viewSwitch = find.byType(SegmentedButton<CalendarViewMode>);
    for (final entry in const [
      (CalendarViewMode.week, '주'),
      (CalendarViewMode.month, '월'),
      (CalendarViewMode.day, '일'),
    ]) {
      container.read(calendarViewModeProvider.notifier).state = entry.$1;
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('빠른 보기'));
      await tester.pumpAndSettle();

      final segment = find.descendant(
        of: viewSwitch,
        matching: find.text(entry.$2),
      );
      await tester.tap(segment);
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);
      expect(container.read(calendarViewModeProvider), entry.$1);
    }

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('app lock covers Settings immediately after backgrounding', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'appLockEnabled': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final secureStorage = _MemorySecureStorage();
    final settingsRepository = SettingsRepository(
      preferences: preferences,
      secureStorage: secureStorage,
    );
    await settingsRepository.saveAppLockPin('13579');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(account: null),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-lock-screen')), findsOneWidget);
    expect(find.text('잠금 상태입니다.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('show-pin-entry-button')));
    await tester.pump();
    for (final digit in ['1', '3', '5', '7', '9']) {
      await tester.tap(find.widgetWithText(TextButton, digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const ValueKey('app-lock-screen')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const ValueKey('app-lock-screen')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('show-pin-entry-button')));
    await tester.pump();
    for (final digit in ['1', '3', '5', '7', '9']) {
      await tester.tap(find.widgetWithText(TextButton, digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('no-PIN app lock obscures only while the app is inactive', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'appLockEnabled': true,
      'appLockMethod': AppLockMethod.noPin.name,
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
            _FakeGoogleDriveAuthService(account: null),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-lock-screen')), findsNothing);
    expect(find.widgetWithText(TextButton, '1'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const ValueKey('app-lock-screen')), findsOneWidget);
    expect(find.text('잠금 상태에서는 화면을 볼 수 없습니다.'), findsOneWidget);
    expect(find.text('잠금 해제'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const ValueKey('app-lock-screen')), findsNothing);
    expect(find.byTooltip('설정'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('macOS PIN lock accepts keyboard digits after unlock button', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'appLockEnabled': true,
      'appLockMethod': AppLockMethod.appPin.name,
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(
      preferences: preferences,
      secureStorage: _MemorySecureStorage(),
    );
    await settingsRepository.saveAppLockPin('13579');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(account: null),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('잠금 상태입니다.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('show-pin-entry-button')));
    await tester.pump();
    for (final key in [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit9,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
      if (key != LogicalKeyboardKey.digit9) {
        final index = switch (key) {
          LogicalKeyboardKey.digit1 => 0,
          LogicalKeyboardKey.digit3 => 1,
          LogicalKeyboardKey.digit5 => 2,
          _ => 3,
        };
        expect(find.byKey(ValueKey('pin-unlock-dot-$index')), findsOneWidget);
      }
    }
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-lock-screen')), findsNothing);
    expect(find.byTooltip('설정'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'macOS biometric cancellation returns to PIN without requesting again',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('daily/apple_authentication');
      final authenticationResult = Completer<bool>();
      var authenticationRequests = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'authenticateBiometricsOrCompanion') {
              authenticationRequests += 1;
              return authenticationResult.future;
            }
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': true,
        'appLockEnabled': true,
        'appLockMethod': AppLockMethod.appPin.name,
        'appLockBiometricsEnabled': true,
      });
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(
        preferences: preferences,
        secureStorage: _MemorySecureStorage(),
      );
      await settingsRepository.saveAppLockPin('13579');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(_FakeNotification()),
            syncServiceProvider.overrideWithValue(_FakeSync()),
            eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
            googleDriveAuthServiceProvider.overrideWithValue(
              _FakeGoogleDriveAuthService(account: null),
            ),
          ],
          child: const DailyApp(),
        ),
      );
      await tester.pump();
      expect(authenticationRequests, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      authenticationResult.complete(false);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(authenticationRequests, 1);
      expect(find.text('PIN 입력'), findsOneWidget);
      expect(find.byKey(const ValueKey('show-pin-entry-button')), findsNothing);

      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Daily restores saved Google Drive session and starts sync without prompt',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      final authService = _FakeGoogleDriveAuthService(
        account: null,
        restoredAccount: const GoogleDriveAccount(
          email: 'restored@example.com',
        ),
      );
      final syncService = _FakeSync();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(_FakeNotification()),
            syncServiceProvider.overrideWithValue(syncService),
            eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
            googleDriveAuthServiceProvider.overrideWithValue(authService),
          ],
          child: const DailyApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(authService.restorePreviousSignInCalls, 1);
      expect(authService.authorizationHeadersCalls, 1);
      expect(authService.signInCalls, 0);
      expect(syncService.startCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Daily retries a temporary Google Drive restore failure without prompting',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      await settingsRepository.saveGoogleAccount(
        const GoogleAccount(email: 'restored@example.com'),
      );
      final authService = _FakeGoogleDriveAuthService(
        account: null,
        restoredAccount: const GoogleDriveAccount(
          email: 'restored@example.com',
        ),
        restoreFailuresRemaining: 1,
      );
      final syncService = _FakeSync();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            notificationServiceProvider.overrideWithValue(_FakeNotification()),
            syncServiceProvider.overrideWithValue(syncService),
            eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
            googleDriveAuthServiceProvider.overrideWithValue(authService),
          ],
          child: const DailyApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(authService.restorePreviousSignInCalls, 2);
      expect(authService.authorizationHeadersCalls, 1);
      expect(authService.signInCalls, 0);
      expect(syncService.startCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('settings shows restored Google Drive account after restart', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final authService = _FakeGoogleDriveAuthService(
      account: null,
      restoredAccount: const GoogleDriveAccount(email: 'restored@example.com'),
    );
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
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(authService.currentAccount?.email, 'restored@example.com');
    await _openAccountSettings(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();

    expect(find.text('restored@example.com'), findsOneWidget);
    expect(authService.signInCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings displays matching app version and build label', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Daily',
      packageName: 'com.littlebit0.daily',
      version: '2.7.1',
      buildNumber: '1',
      buildSignature: '',
    );
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
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    expect(find.text('버전 2.7.1 (2.7.1) · 더블 클릭하여 Github 확인하기'), findsOneWidget);
    final versionTile = find.byKey(const ValueKey('daily-version-github-link'));
    expect(versionTile, findsOneWidget);
    expect(tester.widget<GestureDetector>(versionTile).onDoubleTap, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings rows keep icons and layout at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
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
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    void expectVisibleRowsHaveIcons() {
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile))) {
        expect(tile.leading, isNotNull);
      }
      for (final tile in tester.widgetList<SwitchListTile>(
        find.byType(SwitchListTile),
      )) {
        expect(tile.secondary, isNotNull);
      }
      expect(tester.takeException(), isNull);
    }

    expectVisibleRowsHaveIcons();
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    expect(find.byKey(const ValueKey('siri-shortcut-setup')), findsOneWidget);
    const siriDescription = '시그널 단축어를 추가하고 Siri에서 Daily 명령을 사용합니다.';
    final responsiveDescription = find.byWidgetPredicate(
      (widget) => widget is Text && widget.semanticsLabel == siriDescription,
    );
    expect(responsiveDescription, findsOneWidget);
    final renderedDescription = tester
        .widget<Text>(responsiveDescription)
        .data!;
    expect(renderedDescription, contains('\n'));
    expect(
      renderedDescription.replaceAll('\u2060', '').replaceAll('\n', ' '),
      siriDescription,
    );

    final mainList = find.byType(ListView);
    for (var index = 0; index < 8; index++) {
      await tester.drag(mainList, const Offset(0, -560));
      await tester.pumpAndSettle();
      expectVisibleRowsHaveIcons();
    }
    expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);

    await tester.dragUntilVisible(
      find.widgetWithText(ListTile, '알림'),
      mainList,
      const Offset(0, 560),
    );
    final notificationSettingsTile = find.widgetWithText(ListTile, '알림');
    await tester.ensureVisible(notificationSettingsTile);
    await tester.pumpAndSettle();
    await tester.tap(notificationSettingsTile);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
    expectVisibleRowsHaveIcons();
    final notificationList = find.byType(ListView);
    for (var index = 0; index < 4; index++) {
      await tester.drag(notificationList, const Offset(0, -520));
      await tester.pumpAndSettle();
      expectVisibleRowsHaveIcons();
    }

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-settings-navigation')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    expectVisibleRowsHaveIcons();

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('privacy settings opt in and delete queued analytics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final authService = _FakeGoogleDriveAuthService(account: null);
    final notificationService = _FakeNotification();
    final eventRepository = _FakeEventRepository();
    final analytics = _FakeProductAnalytics();
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
          productAnalyticsProvider.overrideWithValue(analytics),
          notificationServiceProvider.overrideWithValue(notificationService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('anonymous-analytics-toggle')));
    await tester.pump();
    expect(analytics.enabled, isTrue);

    await tester.tap(find.byKey(const ValueKey('delete-analytics-data')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();
    expect(analytics.deleteCalls, 1);
    expect(find.text('전송 대기 분석 데이터를 삭제했습니다.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('PIN setup reveals dots only as digits are entered', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, '앱 잠금'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PIN 잠금').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pin-entry-dots')), findsOneWidget);
    expect(find.byKey(const ValueKey('pin-entry-dot-0')), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, '1'));
    await tester.pump();

    expect(find.byKey(const ValueKey('pin-entry-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('pin-entry-dot-1')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('category RGB picker renders above the category editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(authService),
          googleDriveSyncServiceProvider.overrideWithValue(driveSyncService),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-reorder-list')), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('event-sort-priority-slider')),
      findsOneWidget,
    );
    expect(find.byTooltip('길게 눌러 순서 변경'), findsNWidgets(2));
    final reorderable = tester.widget<ReorderableListView>(
      find.byKey(const ValueKey('category-reorder-list')),
    );
    reorderable.onReorderItem!(0, 1);
    await tester.pumpAndSettle();
    expect(
      settingsRepository.load().categories.map((category) => category.id),
      [EventCategory.holiday.id, EventCategory.basic.id],
    );

    await tester.tap(find.text('분류 우선'));
    await tester.pumpAndSettle();
    expect(
      settingsRepository.load().calendarEventSortPriority,
      CalendarEventSortPriority.category,
    );

    await tester.tap(find.byTooltip('분류 수정').first);
    await tester.pumpAndSettle();

    expect(find.text('분류 수정'), findsOneWidget);
    expect(
      tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .every(
            (chip) => chip.shape is CircleBorder && chip.showCheckmark == false,
          ),
      isTrue,
    );
    for (final chip in find.byType(ChoiceChip).evaluate()) {
      final size = tester.getSize(
        find.byElementPredicate((element) => element == chip),
      );
      expect(size.width, size.height);
    }
    await tester.tap(find.byTooltip('사용자 지정 색상'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('사용자 지정 색상'), findsOneWidget);
    expect(find.byKey(const Key('category-color-palette')), findsOneWidget);
    expect(find.text('R'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('linked Google metadata requires a valid auth session to sync', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    await settingsRepository.saveGoogleAccount(
      const GoogleAccount(email: 'linked@example.com'),
    );
    final authService = _FakeGoogleDriveAuthService(
      account: const GoogleDriveAccount(email: 'linked@example.com'),
      authorizationAvailable: false,
    );
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
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await _openAccountSettings(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    expect(find.text('linked@example.com'), findsOneWidget);
    expect(find.text('Google 다시 연결'), findsOneWidget);
    expect(find.text('지금 동기화'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Google Drive backup and restore are separate actions in one row',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
      FlutterSecureStorage.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      await settingsRepository.saveGoogleAccount(
        const GoogleAccount(email: 'linked@example.com'),
      );
      final authService = _FakeGoogleDriveAuthService(
        account: const GoogleDriveAccount(email: 'linked@example.com'),
      );
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
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      await _openAccountSettings(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -2200));
      await tester.pumpAndSettle();

      final actionRow = find.byKey(
        const ValueKey('google-drive-backup-restore-row'),
      );
      expect(actionRow, findsOneWidget);
      expect(
        find.descendant(of: actionRow, matching: find.text('복원')),
        findsOneWidget,
      );

      await tester.tap(find.text('백업'));
      await tester.pumpAndSettle();
      expect(driveSyncService.syncPendingChangesNowCalls, 1);
      expect(driveSyncService.restoreNowCalls, 0);

      await tester.tap(find.text('복원'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '복원'));
      await tester.pumpAndSettle();
      expect(driveSyncService.restoreNowCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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

  testWidgets(
    'vertical month drag skips blanks and continues into the next month',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 754);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': true,
        'defaultCalendarView': 'month',
      });
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      await settingsRepository.save(
        settingsRepository.load().copyWith(
          monthNavigationMode: MonthNavigationMode.vertical,
        ),
      );

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

      final list = find.byKey(const ValueKey('continuous-month-scroll'));
      await tester.drag(list, const Offset(0, -360));
      await tester.pumpAndSettle();

      final august = find.byKey(const ValueKey('continuous-month-2026-8'));
      final september = find.byKey(const ValueKey('continuous-month-2026-9'));
      final august31 = find.descendant(
        of: august,
        matching: find.byKey(const ValueKey('day-cell-2026-8-31')),
      );
      final september2 = find.descendant(
        of: september,
        matching: find.byKey(const ValueKey('day-cell-2026-9-2')),
      );
      expect(august31, findsOneWidget);
      expect(september2, findsOneWidget);

      final drag = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await drag.down(tester.getCenter(august31));
      await drag.moveTo(tester.getCenter(september2));
      await tester.pump();
      final rangedGrids = tester
          .widgetList<CalendarMonthGrid>(find.byType(CalendarMonthGrid))
          .where(
            (grid) =>
                grid.externalRangeStart != null &&
                grid.externalRangeEnd != null,
          )
          .toList();
      expect(rangedGrids, isNotEmpty);
      expect(rangedGrids.first.externalRangeStart, DateTime(2026, 8, 31));
      expect(rangedGrids.first.externalRangeEnd, DateTime(2026, 9, 2));
      expect(
        find.byKey(const ValueKey('selected-range-2026-8-30')),
        findsWidgets,
      );
      await drag.up();
      await tester.pumpAndSettle();

      expect(find.byType(EventEditorDialog), findsOneWidget);
      final editor = tester.widget<EventEditorDialog>(
        find.byType(EventEditorDialog),
      );
      expect(editor.initialDate, DateTime(2026, 8, 31));
      expect(editor.initialEndDate, DateTime(2026, 9, 2));

      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('vertical month position stays fixed while search opens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 754);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'defaultCalendarView': 'month',
    });
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    await settingsRepository.save(
      settingsRepository.load().copyWith(
        monthNavigationMode: MonthNavigationMode.vertical,
      ),
    );

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

    ListView monthList() => tester.widget<ListView>(
      find.byKey(const ValueKey('continuous-month-scroll')),
    );

    final initialList = monthList();
    initialList.controller!.jumpTo(
      initialList.controller!.offset + initialList.itemExtent! * 2.25,
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DailyApp)),
    );
    final monthBeforeSearch = container.read(visibleMonthProvider);
    final settledList = monthList();
    final itemExtentBefore = settledList.itemExtent!;
    final logicalOffsetBefore =
        settledList.controller!.offset / settledList.itemExtent!;

    await tester.tap(find.byTooltip('검색'));
    await tester.pumpAndSettle();

    final resizedList = monthList();
    final logicalOffsetAfter =
        resizedList.controller!.offset / resizedList.itemExtent!;
    expect(container.read(visibleMonthProvider), monthBeforeSearch);
    expect(resizedList.itemExtent, itemExtentBefore);
    expect(logicalOffsetAfter, closeTo(logicalOffsetBefore, 0.01));

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('day schedule sheet expands and keeps its list draggable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
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
    final month = container.read(visibleMonthProvider);
    final dayCell = find
        .byWidgetPredicate((widget) {
          final key = widget.key;
          return key is ValueKey<String> &&
              key.value.startsWith('day-cell-${month.year}-${month.month}-');
        })
        .hitTestable()
        .first;
    expect(dayCell, findsOneWidget);

    await tester.tap(dayCell);
    await tester.pumpAndSettle();

    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(sheet.initialChildSize, 0.68);
    expect(sheet.minChildSize, 0.4);
    expect(sheet.maxChildSize, 0.96);
    expect(sheet.snap, isTrue);
    expect(
      tester
          .widget<EventDetailsPanel>(find.byType(EventDetailsPanel))
          .scrollController,
      isNotNull,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Daily reschedules saved event notifications on app start', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final event = CalendarEvent(
      id: 'event-notify',
      title: '알림 테스트',
      startAt: DateTime.now().add(const Duration(hours: 1)),
      endAt: DateTime.now().add(const Duration(hours: 2)),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      reminderMinutesBefore: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final notificationService = _FakeNotification();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(notificationService),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(
            _FakeEventRepository(events: [event]),
          ),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(account: null),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(notificationService.initializeCalls, 1);
    expect(notificationService.scheduledEventIds, ['event-notify']);
    expect(notificationService.scheduledImmediateFlags, [false]);

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
    await _openAccountSettings(tester);
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

  testWidgets('local data reset continues when notification cleanup fails', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final authService = _FakeGoogleDriveAuthService(account: null);
    final notificationService = _FakeNotification(
      failCancelEventReminder: true,
      failCancelMorningBriefing: true,
    );
    final eventRepository = _FakeEventRepository(
      events: [
        CalendarEvent(
          id: 'reset-event',
          title: '초기화 테스트',
          startAt: DateTime.now().add(const Duration(hours: 1)),
          endAt: DateTime.now().add(const Duration(hours: 2)),
          allDay: false,
          category: EventCategory.basic,
          colorValue: EventCategory.basic.colorValue,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
    );
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
    await _openAccountSettings(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('로컬 데이터 초기화'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('초기화'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Daily 시작하기'), findsOneWidget);
    expect(eventRepository.clearAllCalls, 1);
    expect(settingsRepository.load().onboardingCompleted, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'settings keeps desktop Google auth active until the user cancels it',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
      FlutterSecureStorage.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      final authService = _FakeGoogleDriveAuthService(
        account: null,
        signInCompleter: Completer<GoogleDriveAccount?>(),
        canCancelOnResume: true,
      );
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
      await _openAccountSettings(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -2200));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Google로 계속'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Google로 계속'));
      await tester.pump();

      expect(authService.signInCalls, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Google 연결 중'),
            )
            .onPressed,
        isNull,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(authService.cancelPendingSignInCalls, 0);
      expect(find.text('연결 취소'), findsOneWidget);
      await tester.tap(find.text('연결 취소'));
      await tester.pump();

      expect(authService.cancelPendingSignInCalls, 1);
      expect(
        find.text('Google Drive 연결이 취소되었습니다. 다시 연결할 수 있습니다.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Google로 계속'),
            )
            .onPressed,
        isNotNull,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('logout clears local accounts and keeps Drive cloud backup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboardingCompleted': true,
      'appleUserIdentifier': 'apple-user',
      'appleEmail': 'hwi@example.com',
    });
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
    await _openAccountSettings(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '로그아웃'));
    await tester.pumpAndSettle();

    expect(authService.signOutCalls, 1);
    expect(driveSyncService.syncNowCalls, 0);
    expect(driveSyncService.syncPendingChangesNowCalls, 1);
    expect(eventRepository.clearAllCalls, 1);
    expect(settingsRepository.load().onboardingCompleted, isFalse);
    expect(settingsRepository.appleAccount(), isNull);
    expect(find.text('Daily 시작하기'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('iOS quick view shows two categorized Todo cards per row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    const work = EventCategory(id: 'work', label: '업무', colorValue: 0xff7c3aed);
    await settingsRepository.save(
      settingsRepository.load().copyWith(
        categories: const [EventCategory.basic, work],
        calendarEventTitleAlignment: CalendarEventTitleAlignment.center,
      ),
    );
    final now = DateTime.now();
    CalendarEvent event(String id, String title, EventCategory category) {
      final start = DateTime(now.year, now.month, 12, 9);
      return CalendarEvent(
        id: id,
        title: title,
        startAt: start,
        endAt: start.add(const Duration(hours: 1)),
        allDay: false,
        category: category,
        colorValue: category.colorValue,
        createdAt: start,
        updatedAt: start,
      );
    }

    final eventRepository = _StreamingEventRepository([
      event('basic-todo', '개인 일정', EventCategory.basic),
      event('work-todo', '업무 일정', work).copyWith(completed: true),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          notificationServiceProvider.overrideWithValue(_FakeNotification()),
          syncServiceProvider.overrideWithValue(_FakeSync()),
          eventRepositoryProvider.overrideWithValue(eventRepository),
          googleDriveAuthServiceProvider.overrideWithValue(
            _FakeGoogleDriveAuthService(),
          ),
        ],
        child: const DailyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('빠른 보기'));
    await tester.pumpAndSettle();

    final basicCard = find.byKey(const ValueKey('quick-todo-category-basic'));
    final workCard = find.byKey(const ValueKey('quick-todo-category-work'));
    expect(basicCard, findsOneWidget);
    expect(workCard, findsOneWidget);
    expect(tester.getTopLeft(basicCard).dy, tester.getTopLeft(workCard).dy);
    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(
      tester.widget<Text>(find.text('업무 일정')).style?.decorationStyle,
      TextDecorationStyle.double,
    );
    expect(
      tester.widget<Text>(find.text('업무 일정')).style?.decorationThickness,
      greaterThanOrEqualTo(2),
    );
    expect(tester.widget<Text>(find.text('업무 일정')).textAlign, TextAlign.start);

    await tester.tap(find.byKey(const ValueKey('quick-todo-open-work-todo')));
    await tester.pumpAndSettle();
    expect(find.text('추가 상세정보가 없습니다.'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _openAccountSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('account-settings-navigation')));
  await tester.pumpAndSettle();
  expect(find.text('계정 설정'), findsOneWidget);
}

class _FakeGoogleDriveAuthService extends GoogleDriveAuthService {
  _FakeGoogleDriveAuthService({
    this.account = const GoogleDriveAccount(email: 'tester@example.com'),
    this.restoredAccount,
    this.signInAccount,
    this.signInCompleter,
    this.canCancelOnResume = false,
    this.restoreFailuresRemaining = 0,
    this.authorizationAvailable = true,
  });

  GoogleDriveAccount? account;
  final GoogleDriveAccount? restoredAccount;
  final GoogleDriveAccount? signInAccount;
  final Completer<GoogleDriveAccount?>? signInCompleter;
  final bool canCancelOnResume;
  int restoreFailuresRemaining;
  final bool authorizationAvailable;
  var cancelPendingSignInCalls = 0;
  var authorizationHeadersCalls = 0;
  var restorePreviousSignInCalls = 0;
  var signInCalls = 0;
  var signOutCalls = 0;

  @override
  GoogleDriveAccount? get currentAccount => account;

  @override
  bool get canCancelPendingSignInOnResume => canCancelOnResume;

  @override
  Future<void> initialize() async {}

  @override
  Future<GoogleDriveAccount?> restorePreviousSignIn() async {
    restorePreviousSignInCalls += 1;
    if (restoreFailuresRemaining > 0) {
      restoreFailuresRemaining -= 1;
      throw const GoogleDriveAuthException('temporary restore failure');
    }
    account ??= restoredAccount;
    return account;
  }

  @override
  Future<GoogleDriveAccount?> signIn({
    bool forceAccountSelection = false,
  }) async {
    signInCalls += 1;
    if (signInCompleter != null) {
      return signInCompleter!.future;
    }
    account ??= signInAccount;
    return account;
  }

  @override
  void cancelPendingSignIn() {
    cancelPendingSignInCalls += 1;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }

  @override
  Future<Map<String, String>?> authorizationHeaders({
    bool promptIfNecessary = false,
  }) async {
    authorizationHeadersCalls += 1;
    if (account == null || !authorizationAvailable) {
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
  var startListeningOnlyCalls = 0;
  var syncNowCalls = 0;
  var syncPendingChangesNowCalls = 0;
  var restoreNowCalls = 0;

  @override
  Future<void> startListeningOnly({bool flushPendingChanges = true}) async {
    startListeningOnlyCalls += 1;
  }

  @override
  Future<void> syncNow({bool promptIfNecessary = false}) async {
    syncNowCalls += 1;
  }

  @override
  Future<void> syncPendingChangesNow({
    bool promptIfNecessary = false,
    bool restoreAfterBackup = false,
  }) async {
    syncPendingChangesNowCalls += 1;
  }

  @override
  Future<void> restoreNow({bool promptIfNecessary = false}) async {
    restoreNowCalls += 1;
  }

  @override
  Future<void> deleteCloudBackup({bool promptIfNecessary = false}) async {
    deleteCloudBackupCalls += 1;
  }
}

class _FakeNotification implements NotificationService {
  _FakeNotification({
    this.failCancelEventReminder = false,
    this.failCancelMorningBriefing = false,
  });

  final bool failCancelEventReminder;
  final bool failCancelMorningBriefing;
  var cancelMorningBriefingCalls = 0;
  var initializeCalls = 0;
  var showTestNotificationCalls = 0;
  final scheduledEventIds = <String>[];
  final scheduledImmediateFlags = <bool>[];

  @override
  Future<void> cancelMorningBriefing() async {
    cancelMorningBriefingCalls += 1;
    if (failCancelMorningBriefing) {
      throw Exception('cancel morning briefing failed');
    }
  }

  @override
  Future<void> cancelEventReminder(
    String eventId, {
    List<int> reminderMinutesBeforeList = const [],
  }) async {
    if (failCancelEventReminder) {
      throw Exception('cancel event reminder failed');
    }
  }

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
  }

  @override
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  }) async {
    scheduledEventIds.add(event.id);
    scheduledImmediateFlags.add(allowImmediate);
  }

  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {}

  @override
  Future<void> showTestNotification() async {
    showTestNotificationCalls += 1;
  }

  @override
  Future<int> pendingNotificationCount() async => scheduledEventIds.length;

  @override
  Future<String> permissionSummary() async => '테스트 권한 · 예약 0개';
}

class _FakeSync implements SyncService {
  @override
  Future<void> queueSettingsBackup() async {}

  var startCalls = 0;

  @override
  Future<void> queueEventDelete(String eventId) async {}

  @override
  Future<void> queueEventUpsert(CalendarEvent event) async {}

  @override
  Future<void> start() async {
    startCalls += 1;
  }
}

class _FakeProductAnalytics implements ProductAnalytics {
  final ValueNotifier<bool> _enabled = ValueNotifier<bool>(false);
  final records = <AnalyticsRecord>[];
  var deleteCalls = 0;

  @override
  bool get enabled => _enabled.value;

  @override
  ValueListenable<bool> get enabledListenable => _enabled;

  @override
  int get pendingEventCount => records.length;

  @override
  Future<void> deletePendingData() async {
    deleteCalls += 1;
    records.clear();
  }

  @override
  void dispose() {
    _enabled.dispose();
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> record(AnalyticsRecord record) async {
    if (enabled) records.add(record);
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    _enabled.value = enabled;
    if (!enabled) await deletePendingData();
  }
}

class _FakeEventRepository implements EventRepository {
  _FakeEventRepository({List<CalendarEvent> events = const []})
    : _events = events;

  final List<CalendarEvent> _events;
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
  Future<List<CalendarEvent>> allEventsForSync() async => _events;

  @override
  Future<List<CalendarEvent>> updateCategoryReferences({
    required EventCategory previous,
    required EventCategory updated,
    required DateTime updatedAt,
  }) async {
    final affected = <CalendarEvent>[];
    for (var index = 0; index < _events.length; index++) {
      final event = _events[index];
      if (event.deletedAt != null || event.category.id != previous.id) {
        continue;
      }
      final next = event.copyWith(
        category: updated,
        colorValue: updated.colorValue,
        updatedAt: updatedAt,
        syncStatus: 'pending',
        holiday: updated.id == EventCategory.holiday.id,
      );
      _events[index] = next;
      affected.add(next);
    }
    return affected;
  }

  @override
  Future<List<CalendarEvent>> eventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async {
    return _events
        .where(
          (event) =>
              event.deletedAt == null &&
              event.startAt.isBefore(rangeEnd) &&
              event.endAt.isAfter(rangeStart),
        )
        .toList();
  }

  @override
  Future<void> markSynced(String eventId) async {}

  @override
  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> remoteEvents, {
    required RestoredEventResolver resolve,
  }) async => const [];

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

class _StreamingEventRepository extends _FakeEventRepository {
  _StreamingEventRepository(List<CalendarEvent> events) : super(events: events);

  @override
  Future<CalendarEvent?> findById(String id) async {
    for (final event in _events) {
      if (event.id == id) return event;
    }
    return null;
  }

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    return Stream.value(
      _events
          .where(
            (event) =>
                event.deletedAt == null &&
                event.startAt.isBefore(rangeEnd) &&
                event.endAt.isAfter(rangeStart),
          )
          .toList(),
    );
  }
}

class _MissingEntitlementSecureStorage extends FlutterSecureStorage {
  const _MissingEntitlementSecureStorage();

  PlatformException get _error => PlatformException(
    code: 'Unexpected security result code',
    message: "A required entitlement isn't present.",
    details: -34018,
  );

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    throw _error;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    throw _error;
  }

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
    throw _error;
  }
}

class _MemorySecureStorage extends FlutterSecureStorage {
  _MemorySecureStorage();

  final _values = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _values.remove(key);
  }
}
