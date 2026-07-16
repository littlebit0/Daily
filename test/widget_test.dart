import 'dart:async';

import 'package:daily/app/daily_app.dart';
import 'package:daily/core/auth/apple_sign_in_service.dart';
import 'package:daily/core/auth/apple_account.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/sync/google_drive_sync_service.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/settings/presentation/settings_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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

  testWidgets(
    'welcome Google Drive button re-enables after desktop auth close',
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

      await tester.tap(find.text('Google로 계속'));
      await tester.pump();

      expect(authService.signInCalls, 1);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Google로 계속'),
            )
            .onPressed,
        isNull,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('일정 없음'), findsWidgets);
    expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DailyApp)),
    );
    final startDate = container.read(selectedDateProvider);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(
      container.read(selectedDateProvider),
      DateTime(startDate.year, startDate.month, startDate.day + 7),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

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
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();

    expect(find.text('restored@example.com'), findsOneWidget);
    expect(authService.signInCalls, 0);

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
    'settings Google Drive connect re-enables after desktop auth close',
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
              find.widgetWithText(FilledButton, 'Google로 계속'),
            )
            .onPressed,
        isNull,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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

  testWidgets('Google logout keeps saved Drive session for next login', (
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
    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('로그아웃'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(authService.signOutCalls, 0);
    expect(driveSyncService.syncNowCalls, 0);
    expect(driveSyncService.syncPendingChangesNowCalls, 1);
    expect(settingsRepository.load().onboardingCompleted, isFalse);
    expect(settingsRepository.appleAccount()?.email, 'hwi@example.com');
    expect(find.text('Daily 시작하기'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _FakeGoogleDriveAuthService extends GoogleDriveAuthService {
  _FakeGoogleDriveAuthService({
    this.account = const GoogleDriveAccount(email: 'tester@example.com'),
    this.restoredAccount,
    this.signInAccount,
    this.signInCompleter,
    this.canCancelOnResume = false,
  });

  GoogleDriveAccount? account;
  final GoogleDriveAccount? restoredAccount;
  final GoogleDriveAccount? signInAccount;
  final Completer<GoogleDriveAccount?>? signInCompleter;
  final bool canCancelOnResume;
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
  var startListeningOnlyCalls = 0;
  var syncNowCalls = 0;
  var syncPendingChangesNowCalls = 0;

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
