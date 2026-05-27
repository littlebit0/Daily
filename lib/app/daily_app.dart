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
      key: ValueKey(
        settings.onboardingCompleted ? 'daily-home' : 'daily-onboarding',
      ),
      title: 'Daily',
      debugShowCheckedModeBanner: false,
      theme: DailyTheme.light(),
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

class _AppHomeState extends ConsumerState<_AppHome> {
  var _servicesStarted = false;

  @override
  void initState() {
    super.initState();
    _startSyncIfConnected();
  }

  @override
  Widget build(BuildContext context) => const MonthCalendarPage();

  Future<void> _startSyncIfConnected() async {
    try {
      final auth = ref.read(googleDriveAuthServiceProvider);
      await auth.initialize();
      if (auth.currentAccount != null) {
        _startPostLoginServices();
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
}
