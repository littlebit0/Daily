import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/apple_sign_in_service.dart';
import '../../../core/alarms/alarm_service.dart';
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
  static const _lastPage = 3;

  final _pageController = PageController();
  _WelcomeAction? _busyAction;
  var _message = '';
  var _googleDriveAttempt = 0;
  var _page = 0;

  bool get _busy => _busyAction != null;

  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(
        () => ref.read(alarmServiceProvider).requestAuthorization(),
      ).catchError((_) => AlarmAuthorizationState.unsupported),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: _page < _lastPage
                    ? TextButton(
                        onPressed: () => _goToPage(_lastPage),
                        child: const Text('건너뛰기'),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (value) => setState(() => _page = value),
                children: [
                  const _WelcomeIntroPage(
                    imagePath: 'assets/onboarding/week-calendar.png',
                    darkImagePath: 'assets/onboarding/dark/week-calendar.png',
                    title: '일정을 한눈에',
                    description: '월간, 주간, 일간 보기로 필요한 일정에 빠르게 집중하세요.',
                  ),
                  const _WelcomeIntroPage(
                    imagePath: 'assets/onboarding/day-calendar.png',
                    darkImagePath: 'assets/onboarding/dark/day-calendar.png',
                    title: '기록하고 바로 알림 받기',
                    description: '자연스럽게 일정을 기록하고 일정 알림과 아침 브리핑을 받아보세요.',
                  ),
                  const _WelcomeIntroPage(
                    imagePath: 'assets/onboarding/dday-calendar.png',
                    darkImagePath: 'assets/onboarding/dark/dday-calendar.png',
                    title: '중요한 날까지 이어서',
                    description:
                        'D-day와 분류를 활용하고 Google Drive로 여러 기기에서 이어서 사용하세요.',
                  ),
                  _buildStartPage(
                    context,
                    compact: compact,
                    showAppleSignIn: showAppleSignIn,
                    canCancelGoogleConnection: canCancelGoogleConnection,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 20 : 28,
                8,
                compact ? 20 : 28,
                12,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 88,
                    child: _page > 0
                        ? TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _goToPage(_page - 1),
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('이전'),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _lastPage + 1,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: index == _page ? 20 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: index == _page
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 88,
                    child: _page < _lastPage
                        ? TextButton(
                            onPressed: () => _goToPage(_page + 1),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [Text('다음'), Icon(Icons.chevron_right)],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartPage(
    BuildContext context, {
    required bool compact,
    required bool showAppleSignIn,
    required bool canCancelGoogleConnection,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 20 : 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 54,
                color: Color(0xff2563eb),
              ),
              const SizedBox(height: 16),
              Text(
                'Daily 시작하기',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Apple 또는 Google 계정을 연결하거나 계정 없이 로컬로 시작할 수 있습니다.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              if (showAppleSignIn) ...[
                FilledButton.icon(
                  onPressed: _busy ? null : _startWithApple,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  icon: _busyAction == _WelcomeAction.apple
                      ? const SizedBox.square(
                          dimension: 18,
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
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.calendar_today_outlined),
                label: const Text('로컬로 시작'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _connectAndRestore,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xff3c4043),
                  disabledBackgroundColor: const Color(0xfff1f3f4),
                  disabledForegroundColor: const Color(0xff9aa0a6),
                  side: const BorderSide(color: Color(0xffdadce0)),
                ),
                icon: _busyAction == _WelcomeAction.googleDrive
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const _GoogleMark(),
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
                    ? const SizedBox.square(
                        dimension: 18,
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
    );
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page.clamp(0, _lastPage),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
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

class _WelcomeIntroPage extends StatelessWidget {
  const _WelcomeIntroPage({
    required this.imagePath,
    required this.darkImagePath,
    required this.title,
    required this.description,
  });

  final String imagePath;
  final String darkImagePath;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: Column(
          children: [
            Text(
              'Daily 시작하기',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Image.asset(
                      Theme.of(context).brightness == Brightness.dark
                          ? darkImagePath
                          : imagePath,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 20,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.39;
    final strokeWidth = size.shortestSide * 0.19;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xff4285f4);
    canvas.drawArc(rect, -0.18, 1.70, false, paint);
    paint.color = const Color(0xff34a853);
    canvas.drawArc(rect, 1.52, 1.14, false, paint);
    paint.color = const Color(0xfffbbc05);
    canvas.drawArc(rect, 2.66, 0.82, false, paint);
    paint.color = const Color(0xffea4335);
    canvas.drawArc(rect, 3.48, 1.48, false, paint);

    final blue = Paint()
      ..color = const Color(0xff4285f4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - strokeWidth / 2,
        radius,
        strokeWidth,
      ),
      blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
