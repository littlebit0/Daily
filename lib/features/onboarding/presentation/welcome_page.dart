import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/apple_sign_in_service.dart';
import '../../../core/auth/google_account.dart';
import '../../../core/di/app_providers.dart';
import '../../../core/sync/google_drive_auth_service.dart';

enum _WelcomeAction { apple, local, googleDrive, notification }

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  _WelcomeAction? _busyAction;
  var _message = '';
  var _googleDriveAttempt = 0;

  bool get _busy => _busyAction != null;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 560;
    final appleSignInService = ref.watch(appleSignInServiceProvider);
    final showAppleSignIn = appleSignInService.isSupportedPlatform;
    final canCancelGoogleConnection =
        _busyAction == _WelcomeAction.googleDrive &&
        ref
            .watch(googleDriveAuthServiceProvider)
            .canCancelPendingSignInOnResume;

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
                    'Apple 또는 Google 계정을 Daily 계정에 연결할 수 있습니다. Google 로그인 시 Google Drive를 통한 기기 간 동기화도 함께 사용할 수 있습니다. '
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
                    label: Text(
                      _busyAction == _WelcomeAction.googleDrive
                          ? 'Google 연결 중'
                          : 'Google로 계속',
                    ),
                  ),
                  if (canCancelGoogleConnection) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _cancelGoogleDriveSignIn,
                      icon: const Icon(Icons.close),
                      label: const Text('연결 취소'),
                    ),
                  ],
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
      final restoredGoogleSync = await _restoreLinkedGoogleDriveSync();
      if (!mounted) {
        return;
      }
      setState(() {
        _message = restoredGoogleSync
            ? 'Apple 로그인이 완료되었습니다. 연결된 Google Drive 동기화를 복원했습니다.'
            : 'Apple 로그인이 완료되었습니다.';
      });
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
      _message = 'Google 로그인 창을 여는 중입니다.';
    });
    try {
      final connected = await _connectGoogleDriveAndRestore(
        cancelMessage: 'Google 로그인이 취소되었습니다.',
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
  }) async {
    final attempt = ++_googleDriveAttempt;
    try {
      final authService = ref.read(googleDriveAuthServiceProvider);
      final account = await authService.signIn(forceAccountSelection: true);
      if (!_isCurrentGoogleDriveAttempt(attempt)) {
        return false;
      }
      if (account == null) {
        if (mounted) {
          setState(() => _message = cancelMessage);
        }
        return false;
      }

      final headers = await authService.authorizationHeaders(
        promptIfNecessary: true,
      );
      if (!_isCurrentGoogleDriveAttempt(attempt)) {
        return false;
      }
      if (headers == null) {
        throw const GoogleDriveAuthException(
          'Google Drive 권한 승인이 완료되지 않았습니다. 다시 연결해 주세요.',
        );
      }
      await ref
          .read(settingsRepositoryProvider)
          .saveGoogleAccount(
            GoogleAccount(
              email: account.email,
              displayName: account.displayName,
            ),
          );

      final syncService = ref.read(googleDriveSyncServiceProvider);
      await syncService.startListeningOnly(flushPendingChanges: false);
      if (!_isCurrentGoogleDriveAttempt(attempt)) {
        return false;
      }
      await syncService.syncPendingChangesNow(
        promptIfNecessary: false,
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

  Future<bool> _restoreLinkedGoogleDriveSync() async {
    final linkedGoogle = ref
        .read(settingsRepositoryProvider)
        .dailyAccount()
        ?.googleAccount;
    if (linkedGoogle == null) {
      return false;
    }

    try {
      final authService = ref.read(googleDriveAuthServiceProvider);
      final restored = await authService.restorePreviousSignIn();
      if (restored == null || !_sameEmail(restored.email, linkedGoogle.email)) {
        return false;
      }
      final headers = await authService.authorizationHeaders();
      if (headers == null) {
        return false;
      }
      final syncService = ref.read(googleDriveSyncServiceProvider);
      await syncService.startListeningOnly(flushPendingChanges: false);
      await syncService.syncPendingChangesNow(restoreAfterBackup: true);
      return true;
    } on Object {
      return false;
    }
  }

  bool _sameEmail(String left, String right) =>
      left.trim().toLowerCase() == right.trim().toLowerCase();

  bool _isCurrentGoogleDriveAttempt(int attempt) {
    return _googleDriveAttempt == attempt;
  }

  void _cancelGoogleDriveSignIn() {
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
