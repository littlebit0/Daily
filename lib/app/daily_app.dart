import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/app_providers.dart';
import '../core/auth/google_account.dart';
import '../features/calendar/presentation/month_calendar_page.dart';
import '../features/onboarding/presentation/welcome_page.dart';
import 'daily_theme.dart';

class DailyApp extends ConsumerWidget {
  const DailyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp(
      key: ValueKey(
        settings.onboardingCompleted ? 'daily-home' : 'daily-onboarding',
      ),
      title: 'Daily',
      debugShowCheckedModeBanner: false,
      theme: DailyTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(settings.appTextSize.scale)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: settings.onboardingCompleted
          ? settings.appLockEnabled
                ? const _AppLockGate(child: _AppHome())
                : const _AppHome()
          : const WelcomePage(),
    );
  }
}

class _AppLockGate extends ConsumerStatefulWidget {
  const _AppLockGate({required this.child});

  final Widget child;

  @override
  ConsumerState<_AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<_AppLockGate>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  var _unlocked = false;
  var _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _controller.clear();
      if (mounted) {
        setState(() => _unlocked = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) {
      return widget.child;
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline, size: 42),
                  const SizedBox(height: 18),
                  Text(
                    'Daily 잠금 해제',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _unlock(),
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      errorText: _error.isEmpty ? null : _error,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(onPressed: _unlock, child: const Text('잠금 해제')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _unlock() async {
    final ok = await ref
        .read(settingsRepositoryProvider)
        .verifyAppLockPin(_controller.text.trim());
    if (!mounted) {
      return;
    }
    if (ok) {
      setState(() {
        _unlocked = true;
        _error = '';
      });
    } else {
      setState(() => _error = 'PIN이 일치하지 않습니다.');
    }
  }
}

class _AppHome extends ConsumerStatefulWidget {
  const _AppHome();

  @override
  ConsumerState<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends ConsumerState<_AppHome>
    with WidgetsBindingObserver {
  var _servicesStarted = false;
  ValueNotifier<int>? _settingsRevisionNotifier;
  VoidCallback? _settingsRevisionListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLocalNotificationServices();
    _startSyncIfConnected();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final listener = _settingsRevisionListener;
    final notifier = _settingsRevisionNotifier;
    if (listener != null) {
      notifier?.removeListener(listener);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startSyncIfConnected();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _syncBeforeBackgroundOrExit();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => const MonthCalendarPage();

  Future<void> _startSyncIfConnected() async {
    try {
      final auth = ref.read(googleDriveAuthServiceProvider);
      final account = await auth.restorePreviousSignIn();
      if (account != null) {
        final settingsRepository = ref.read(settingsRepositoryProvider);
        var dailyAccount = settingsRepository.dailyAccount();
        if (!settingsRepository.hasStoredDailyAccount) {
          // Migrate the pre-Daily-account Google session once. New Apple-only
          // accounts always persist first, so they never attach Google silently.
          await settingsRepository.saveGoogleAccount(
            GoogleAccount(
              email: account.email,
              displayName: account.displayName,
            ),
          );
          dailyAccount = settingsRepository.dailyAccount();
        }
        final linkedGoogleEmail = dailyAccount?.googleAccount?.email;
        if (linkedGoogleEmail == null ||
            linkedGoogleEmail.toLowerCase() != account.email.toLowerCase()) {
          return;
        }
        final headers = await auth.authorizationHeaders();
        if (headers != null) {
          _startPostLoginServices();
        }
        return;
      }
      if (!Platform.isWindows && !Platform.isMacOS) {
        return;
      }
      final headers = await auth.authorizationHeaders();
      if (headers != null) {
        _startPostLoginServices();
      }
    } on Object {
      // Google Drive sync is optional; local calendar use stays available.
    }
  }

  void _startPostLoginServices() {
    _listenForSyncedSettings();
    if (_servicesStarted) {
      unawaited(
        Future.microtask(() async {
          await _syncGoogleDriveSnapshot();
        }).catchError((_) {}),
      );
      return;
    }
    _servicesStarted = true;
    unawaited(
      Future.microtask(() async {
        await ref.read(syncServiceProvider).start();
        _refreshSettingsState();
      }).catchError((_) {}),
    );
  }

  void _listenForSyncedSettings() {
    if (_settingsRevisionListener != null) {
      return;
    }
    void listener() => _refreshSettingsState();
    final notifier = ref
        .read(googleDriveSyncServiceProvider)
        .settingsRevisionNotifier;
    _settingsRevisionNotifier = notifier;
    _settingsRevisionListener = listener;
    notifier.addListener(listener);
  }

  void _syncBeforeBackgroundOrExit() {
    unawaited(
      Future.microtask(() async {
        await ref.read(googleDriveSyncServiceProvider).syncPendingChangesNow();
      }).catchError((_) {}),
    );
  }

  Future<void> _syncGoogleDriveSnapshot() async {
    await ref
        .read(googleDriveSyncServiceProvider)
        .syncPendingChangesNow(restoreAfterBackup: true);
    _refreshSettingsState();
  }

  void _refreshSettingsState() {
    if (!mounted) {
      return;
    }
    ref.read(appSettingsProvider.notifier).state = ref
        .read(settingsRepositoryProvider)
        .load();
  }

  void _startLocalNotificationServices() {
    unawaited(
      Future.microtask(() async {
        final notificationService = ref.read(notificationServiceProvider);
        await notificationService.initialize();

        final settings = ref.read(appSettingsProvider);
        if (settings.morningBriefingEnabled) {
          await notificationService.scheduleMorningBriefing(
            hour: settings.morningBriefingHour,
            minute: settings.morningBriefingMinute,
          );
        }

        final events = await ref
            .read(eventRepositoryProvider)
            .allEventsForSync();
        for (final event in events) {
          if (!event.isDeleted) {
            await notificationService.scheduleEventReminder(event);
          }
        }
      }).catchError((_) {}),
    );
  }
}
