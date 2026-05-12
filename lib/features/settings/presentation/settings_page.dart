import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/settings/app_settings.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _apiKeyController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _backupMessage = '';
  var _authBusy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final key = await ref.read(settingsRepositoryProvider).geminiApiKey();
      if (mounted) {
        _apiKeyController.text = key ?? '';
      }
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('알림'),
          DropdownButtonFormField<int>(
            initialValue: settings.defaultReminderMinutes,
            decoration: const InputDecoration(labelText: '기본 일정 알림'),
            items: const [
              DropdownMenuItem(value: 10, child: Text('10분 전')),
              DropdownMenuItem(value: 30, child: Text('30분 전')),
              DropdownMenuItem(value: 60, child: Text('1시간 전')),
              DropdownMenuItem(value: 1440, child: Text('하루 전')),
            ],
            onChanged: (value) {
              if (value != null) {
                _save(settings.copyWith(defaultReminderMinutes: value));
              }
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('아침 브리핑'),
            subtitle: Text(
              '${settings.morningBriefingHour.toString().padLeft(2, '0')}:${settings.morningBriefingMinute.toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.schedule),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: settings.morningBriefingHour,
                  minute: settings.morningBriefingMinute,
                ),
              );
              if (picked != null) {
                final updated = settings.copyWith(
                  morningBriefingHour: picked.hour,
                  morningBriefingMinute: picked.minute,
                );
                await _save(updated);
                await ref
                    .read(notificationServiceProvider)
                    .scheduleMorningBriefing(
                      hour: picked.hour,
                      minute: picked.minute,
                    );
              }
            },
          ),
          const SizedBox(height: 22),
          _SectionTitle('AI'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.aiEnabled,
            title: const Text('Gemini 사용'),
            onChanged: (value) => _save(settings.copyWith(aiEnabled: value)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.blockSensitiveAi,
            title: const Text('민감 문장 AI 차단'),
            onChanged: (value) =>
                _save(settings.copyWith(blockSensitiveAi: value)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Gemini API 키',
              suffixIcon: IconButton(
                tooltip: '저장',
                onPressed: _saveApiKey,
                icon: const Icon(Icons.save_outlined),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _SectionTitle('백업'),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _backup,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('지금 백업'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _restore,
                  icon: const Icon(Icons.restore),
                  label: const Text('복원'),
                ),
              ),
            ],
          ),
          if (_backupMessage.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _backupMessage,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
          const SizedBox(height: 22),
          _SectionTitle('동기화'),
          authState.when(
            data: (user) => user == null
                ? _SignedOutSyncSettings(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    busy: _authBusy,
                    onSignIn: () => _authenticate(createAccount: false),
                    onCreateAccount: () => _authenticate(createAccount: true),
                  )
                : _SignedInSyncSettings(
                    email: user.email ?? user.uid,
                    onSignOut: _signOut,
                  ),
            error: (error, stackTrace) => Text(
              'Firebase 설정 필요: $error',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            loading: () => const LinearProgressIndicator(),
          ),
        ],
      ),
    );
  }

  Future<void> _save(AppSettings settings) async {
    await ref.read(settingsRepositoryProvider).save(settings);
    ref.read(appSettingsProvider.notifier).state = settings;
  }

  Future<void> _saveApiKey() async {
    await ref
        .read(settingsRepositoryProvider)
        .saveGeminiApiKey(_apiKeyController.text);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('API 키를 저장했습니다.')));
    }
  }

  Future<void> _backup() async {
    final path = await ref.read(backupServiceProvider).backupNow();
    setState(() => _backupMessage = '백업 완료: $path');
  }

  Future<void> _restore() async {
    try {
      await ref.read(backupServiceProvider).restoreLatest();
      setState(() => _backupMessage = '복원 완료');
    } on Object catch (error) {
      setState(() => _backupMessage = '$error');
    }
  }

  Future<void> _authenticate({required bool createAccount}) async {
    setState(() => _authBusy = true);
    try {
      final auth = ref.read(firebaseAuthServiceProvider);
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final credential = createAccount
          ? await auth.createAccount(email: email, password: password)
          : await auth.signIn(email: email, password: password);
      if (credential == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Firebase 설정이 아직 준비되지 않았습니다.')),
        );
      }
      await ref.read(syncServiceProvider).start();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _authBusy = false);
      }
    }
  }

  Future<void> _signOut() async {
    await ref.read(firebaseAuthServiceProvider).signOut();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _SignedOutSyncSettings extends StatelessWidget {
  const _SignedOutSyncSettings({
    required this.emailController,
    required this.passwordController,
    required this.busy,
    required this.onSignIn,
    required this.onCreateAccount,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool busy;
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: '이메일'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: '비밀번호'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : onSignIn,
                child: const Text('로그인'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onCreateAccount,
                child: const Text('계정 만들기'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignedInSyncSettings extends StatelessWidget {
  const _SignedInSyncSettings({required this.email, required this.onSignOut});

  final String email;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(email),
      subtitle: const Text('Firestore 실시간 동기화 사용 중'),
      trailing: TextButton(onPressed: onSignOut, child: const Text('로그아웃')),
    );
  }
}
