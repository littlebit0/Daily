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
          ? settings.appLockEnabled
                ? const _AppLockGate(child: _GoogleAccountGate())
                : const _GoogleAccountGate()
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
