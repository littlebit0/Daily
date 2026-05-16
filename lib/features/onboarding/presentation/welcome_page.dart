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
  String? _email;

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
                    'Google Drive 동기화를 연결하면 백업을 복원하고 이후 변경 사항을 자동으로 저장합니다.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xff5f6875),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _busy ? null : _connectAndRestore,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(_email == null ? 'Google로 로그인' : _email!),
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
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _finish,
                    child: const Text('시작하기'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : _finish,
                    child: const Text('나중에 하기'),
                  ),
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
      final account = await ref.read(googleDriveAuthServiceProvider).signIn();
      if (account == null) {
        if (mounted) {
          setState(() => _message = 'Google 로그인이 취소되었습니다.');
        }
        return;
      }
      await ref
          .read(googleDriveSyncServiceProvider)
          .syncNow(promptIfNecessary: true);
      if (!mounted) {
        return;
      }
      ref.read(appSettingsProvider.notifier).state = ref
          .read(settingsRepositoryProvider)
          .load();
      setState(() {
        _email = account.email;
        _message = 'Google Drive 동기화가 준비되었습니다.';
      });
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

  Future<void> _finish() async {
    final settings = ref.read(appSettingsProvider);
    final updated = settings.copyWith(onboardingCompleted: true);
    await ref.read(settingsRepositoryProvider).save(updated);
    ref.read(appSettingsProvider.notifier).state = updated;
  }
}
