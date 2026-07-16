import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/apple_sign_in_service.dart';
import '../../../core/di/app_providers.dart';

enum _WelcomeAction { apple, local, googleDrive, notification }

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage>
    with WidgetsBindingObserver {
  _WelcomeAction? _busyAction;
  var _message = '';
  var _googleDriveAttempt = 0;

  bool get _busy => _busyAction != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cancelDesktopGoogleDriveSignInIfPending();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 560;
    final appleSignInService = ref.watch(appleSignInServiceProvider);
    final showAppleSignIn = appleSignInService.isSupportedPlatform;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: EdgeInsets.all(compact ? 20 : 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 54,
                    color: Color(0xff2563eb),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Daily 시작하기',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Apple 또는 Google로 로그인하면 Google Drive를 통해 기기 간 동기화를 자동으로 사용합니다. '
                    '계정 없이 로컬로도 시작할 수 있습니다.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xff5f6875),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (showAppleSignIn) ...[
                    FilledButton.icon(
                      onPressed: _busy ? null : _startWithApple,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      icon: _busyAction == _WelcomeAction.apple
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.apple),
                      label: const Text('Apple로 계속'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  FilledButton.icon(
                    onPressed: _busy ? null : _startLocal,
                    icon: _busyAction == _WelcomeAction.local
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.calendar_today_outlined),
                    label: const Text('로컬로 시작'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _connectAndRestore,
                    icon: _busyAction == _WelcomeAction.googleDrive
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Google로 계속'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _requestNotificationPermission,
                    icon: _busyAction == _WelcomeAction.notification
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.notifications_active_outlined),
                    label: const Text('알림 권한 허용'),
                  ),
                  if (_message.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startWithApple() async {
    setState(() {
      _busyAction = _WelcomeAction.apple;
      _message = 'Apple 로그인 창을 여는 중입니다.';
    });
    try {
      final account = await ref.read(appleSignInServiceProvider).signIn();
      if (account == null) {
        if (mounted) {
          setState(() => _message = 'Apple 로그인이 취소되었습니다.');
        }
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Apple 로그인이 완료되었습니다. Google Drive 동기화를 연결하는 중입니다.';
      });
      final googleConnected = await _connectGoogleDriveAndRestore(
        cancelMessage:
            'Google Drive 연결이 취소되었습니다. Apple로 계속하려면 Google Drive 연결이 필요합니다.',
        preferSilentRestore: true,
      );
      if (!googleConnected) {
        return;
      }
      await _completeOnboarding();
    } on AppleSignInException catch (error) {
      if (mounted) {
        setState(() => _message = error.message);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _message = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busyAction = null);
      }
    }
  }

  Future<void> _connectAndRestore() async {
    setState(() {
      _busyAction = _WelcomeAction.googleDrive;
      _message = 'Google Drive 연결 창을 여는 중입니다.';
    });
    try {
      final connected = await _connectGoogleDriveAndRestore(
        cancelMessage: 'Google Drive 연결이 취소되었습니다.',
        preferSilentRestore: false,
      );
      if (connected) {
        await _completeOnboarding();
      }
    } finally {
      if (mounted) {
        setState(() => _busyAction = null);
      }
    }
  }

  Future<bool> _connectGoogleDriveAndRestore({
    required String cancelMessage,
    required bool preferSilentRestore,
  }) async {
    final attempt = ++_googleDriveAttempt;
    try {
      final authService = ref.read(googleDriveAuthServiceProvider);
      var account = preferSilentRestore
          ? await authService.restorePreviousSignIn()
          : null;
      if (!_isCurrentGoogleDriveAttempt(attempt)) {
        return false;
      }
      if (account == null && preferSilentRestore) {
        if (mounted) {
          setState(() => _message = 'Google 로그인 창을 여는 중입니다.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        if (!_isCurrentGoogleDriveAttempt(attempt)) {
          return false;
        }
      }
      account ??= await authService.signIn(forceAccountSelection: true);
      if (!_isCurrentGoogleDriveAttempt(attempt)) {
        return false;
      }
      if (account == null) {
        if (mounted) {
          setState(() => _message = cancelMessage);
        }
        return false;
      }

      final syncService = ref.read(googleDriveSyncServiceProvider);
      await syncService.startListeningOnly(flushPendingChanges: false);
      if (!_isCurrentGoogleDriveAttempt(attempt)) {
        return false;
      }
      await syncService.syncPendingChangesNow(
        promptIfNecessary: true,
        restoreAfterBackup: true,
      );
      if (!_isCurrentGoogleDriveAttempt(attempt)) {
        return false;
      }

      return true;
    } on UnsupportedError catch (error) {
      if (mounted && _isCurrentGoogleDriveAttempt(attempt)) {
        setState(() => _message = error.message ?? '$error');
      }
    } on Object catch (error) {
      if (mounted && _isCurrentGoogleDriveAttempt(attempt)) {
        setState(() => _message = '$error');
      }
    }
    return false;
  }

  bool _isCurrentGoogleDriveAttempt(int attempt) {
    return _googleDriveAttempt == attempt;
  }

  void _cancelDesktopGoogleDriveSignInIfPending() {
    if (_busyAction != _WelcomeAction.googleDrive) {
      return;
    }
    final authService = ref.read(googleDriveAuthServiceProvider);
    if (!authService.canCancelPendingSignInOnResume) {
      return;
    }
    authService.cancelPendingSignIn();
    _googleDriveAttempt += 1;
    if (mounted) {
      setState(() {
        _busyAction = null;
        _message = 'Google Drive 연결이 취소되었습니다. 다시 연결할 수 있습니다.';
      });
    }
  }

  Future<void> _startLocal() async {
    setState(() {
      _busyAction = _WelcomeAction.local;
      _message = '';
    });
    try {
      await _completeOnboarding();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _message = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busyAction = null);
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    setState(() {
      _busyAction = _WelcomeAction.notification;
      _message = '알림 권한 요청을 여는 중입니다.';
    });
    try {
      await ref.read(notificationServiceProvider).initialize();
      if (mounted) {
        setState(() => _message = '알림 권한 설정을 확인했습니다.');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _message = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busyAction = null);
      }
    }
  }

  Future<void> _completeOnboarding() async {
    final settings = ref
        .read(settingsRepositoryProvider)
        .load()
        .copyWith(onboardingCompleted: true);
    await ref.read(settingsRepositoryProvider).save(settings);
    if (!mounted) {
      return;
    }
    ref.read(appSettingsProvider.notifier).state = settings;
  }
}
