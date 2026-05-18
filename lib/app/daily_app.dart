import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/app_providers.dart';
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
      title: 'Daily',
      debugShowCheckedModeBanner: false,
      theme: DailyTheme.light(),
      home: settings.onboardingCompleted
          ? const _GoogleAccountGate()
          : const WelcomePage(),
    );
  }
}

class _GoogleAccountGate extends ConsumerStatefulWidget {
  const _GoogleAccountGate();

  @override
  ConsumerState<_GoogleAccountGate> createState() => _GoogleAccountGateState();
}

class _GoogleAccountGateState extends ConsumerState<_GoogleAccountGate> {
  late final Future<bool> _accountFuture;
  var _servicesStarted = false;
  var _loginResetQueued = false;

  @override
  void initState() {
    super.initState();
    _accountFuture = _hasGoogleAccount();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _accountFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupLoadingPage();
        }

        if (snapshot.data == true) {
          _startPostLoginServices();
          return const MonthCalendarPage();
        }

        _queueReturnToLogin();
        return const WelcomePage();
      },
    );
  }

  Future<bool> _hasGoogleAccount() async {
    try {
      final auth = ref.read(googleDriveAuthServiceProvider);
      await auth.initialize();
      if (auth.currentAccount != null) {
        return true;
      }
      final headers = await auth.authorizationHeaders();
      return headers != null;
    } on Object {
      return false;
    }
  }

  void _startPostLoginServices() {
    if (_servicesStarted) {
      return;
    }
    _servicesStarted = true;
    unawaited(
      Future.microtask(() async {
        await ref.read(syncServiceProvider).start();
      }).catchError((_) {}),
    );
  }

  void _queueReturnToLogin() {
    if (_loginResetQueued) {
      return;
    }
    _loginResetQueued = true;
    unawaited(
      Future.microtask(() async {
        final settings = ref.read(appSettingsProvider);
        if (!settings.onboardingCompleted) {
          return;
        }
        final updated = settings.copyWith(onboardingCompleted: false);
        await ref.read(settingsRepositoryProvider).save(updated);
        ref.read(appSettingsProvider.notifier).state = updated;
      }),
    );
  }
}

class _StartupLoadingPage extends StatelessWidget {
  const _StartupLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      ),
    );
  }
}
