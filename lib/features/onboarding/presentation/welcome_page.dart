import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  var _busy = false;
  var _message = '';

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 560;

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
                    'Daily는 바로 로컬에서 사용할 수 있습니다. Google 계정을 연결하면 '
                    '백업을 복원하고 이후 변경 사항을 자동으로 동기화합니다.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xff5f6875),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _busy ? null : _startLocal,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: const Text('로컬로 시작'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _connectAndRestore,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Google로 로그인 및 복원'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _requestNotificationPermission,
                    icon: const Icon(Icons.notifications_active_outlined),
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

  Future<void> _connectAndRestore() async {
    setState(() {
      _busy = true;
      _message = 'Google 로그인 창을 여는 중입니다.';
    });
    try {
      final account = await ref
          .read(googleDriveAuthServiceProvider)
          .signIn(forceAccountSelection: true);
      if (account == null) {
        if (mounted) {
          setState(() => _message = 'Google 로그인이 취소되었습니다.');
        }
        return;
      }

      setState(() => _message = '계정 백업을 확인하는 중입니다.');
      await ref
          .read(googleDriveSyncServiceProvider)
          .syncNow(promptIfNecessary: true);

      final restoredSettings = ref.read(settingsRepositoryProvider).load();
      final updated = restoredSettings.copyWith(onboardingCompleted: true);
      await ref.read(settingsRepositoryProvider).save(updated);
      if (!mounted) {
        return;
      }
      ref.read(appSettingsProvider.notifier).state = updated;
    } on UnsupportedError catch (error) {
      if (mounted) {
        setState(() => _message = error.message ?? '$error');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _message = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _startLocal() async {
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final settings = ref
          .read(settingsRepositoryProvider)
          .load()
          .copyWith(onboardingCompleted: true);
      await ref.read(settingsRepositoryProvider).save(settings);
      if (!mounted) {
        return;
      }
      ref.read(appSettingsProvider.notifier).state = settings;
    } on Object catch (error) {
      if (mounted) {
        setState(() => _message = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    setState(() {
      _busy = true;
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
        setState(() => _busy = false);
      }
    }
  }
}
