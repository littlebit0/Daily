import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../events/domain/event_category.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _apiKeyController = TextEditingController();
  var _backupMessage = '';
  var _syncMessage = '';
  var _syncBusy = false;
  String? _driveEmail;

  static const _categoryColors = [
    0xff2563eb,
    0xff10b981,
    0xfff59e0b,
    0xffec4899,
    0xff8b5cf6,
    0xff14b8a6,
    0xff64748b,
    0xffef4444,
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final key = await ref.read(settingsRepositoryProvider).geminiApiKey();
      await ref.read(googleDriveAuthServiceProvider).initialize();
      final driveAccount = ref
          .read(googleDriveAuthServiceProvider)
          .currentAccount;
      if (mounted) {
        _apiKeyController.text = key ?? '';
        setState(() => _driveEmail = driveAccount?.email);
      }
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          _SettingsSection(
            title: '알림',
            children: [
              _PresetMinutesTile(
                title: '기본 일정 알림',
                value: settings.defaultReminderMinutes,
                presets: const [0, 10, 30, 60, 1440],
                onChanged: (value) =>
                    _save(settings.copyWith(defaultReminderMinutes: value)),
                onCustom: () async {
                  final value = await _showNumberDialog(
                    context: context,
                    title: '기본 알림 직접 입력',
                    label: '몇 분 전에 알릴까요?',
                    initialValue: settings.defaultReminderMinutes,
                  );
                  if (value != null && value >= 0) {
                    await _save(
                      settings.copyWith(defaultReminderMinutes: value),
                    );
                  }
                },
              ),
              const Divider(height: 1),
              _TimeTile(
                title: '종일 일정 알림 시간',
                subtitle: '종일 일정의 알림 기준 시간',
                hour: settings.allDayReminderHour,
                minute: settings.allDayReminderMinute,
                onChanged: (time) => _save(
                  settings.copyWith(
                    allDayReminderHour: time.hour,
                    allDayReminderMinute: time.minute,
                  ),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.morningBriefingEnabled,
                title: const Text('아침 브리핑'),
                subtitle: const Text('매일 지정한 시간에 오늘 일정을 알려줍니다.'),
                onChanged: (value) async {
                  final updated = settings.copyWith(
                    morningBriefingEnabled: value,
                  );
                  await _save(updated);
                  if (value) {
                    await ref
                        .read(notificationServiceProvider)
                        .scheduleMorningBriefing(
                          hour: updated.morningBriefingHour,
                          minute: updated.morningBriefingMinute,
                        );
                  } else {
                    await ref
                        .read(notificationServiceProvider)
                        .cancelMorningBriefing();
                  }
                },
              ),
              if (settings.morningBriefingEnabled)
                _TimeTile(
                  title: '아침 브리핑 시간',
                  subtitle: '브리핑을 받을 시간',
                  hour: settings.morningBriefingHour,
                  minute: settings.morningBriefingMinute,
                  onChanged: (time) async {
                    final updated = settings.copyWith(
                      morningBriefingHour: time.hour,
                      morningBriefingMinute: time.minute,
                    );
                    await _save(updated);
                    await ref
                        .read(notificationServiceProvider)
                        .scheduleMorningBriefing(
                          hour: time.hour,
                          minute: time.minute,
                        );
                  },
                ),
              const Divider(height: 1),
              _DdayOffsetsTile(
                offsets: settings.dDayReminderOffsets,
                onChanged: (offsets) =>
                    _save(settings.copyWith(dDayReminderOffsets: offsets)),
                onCustom: () async {
                  final value = await _showNumberDialog(
                    context: context,
                    title: 'D-day 알림 직접 입력',
                    label: 'D-day 기준 일수. 예: -7, 0',
                    initialValue: -7,
                  );
                  if (value != null) {
                    final offsets = {
                      ...settings.dDayReminderOffsets,
                      value,
                    }.toList()..sort();
                    await _save(
                      settings.copyWith(dDayReminderOffsets: offsets),
                    );
                  }
                },
              ),
            ],
          ),
          _SettingsSection(
            title: '달력',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('주 시작 요일'),
                subtitle: const Text('달력의 첫 번째 요일을 선택합니다.'),
                trailing: SegmentedButton<bool>(
                  selected: {settings.weekStartsOnMonday},
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('일')),
                    ButtonSegment(value: true, label: Text('월')),
                  ],
                  onSelectionChanged: (selection) {
                    _save(
                      settings.copyWith(weekStartsOnMonday: selection.first),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.showLunarDates,
                title: const Text('음력 표시'),
                subtitle: const Text('월 달력의 각 날짜에 음력 날짜를 함께 표시합니다.'),
                onChanged: (value) =>
                    _save(settings.copyWith(showLunarDates: value)),
              ),
            ],
          ),
          _SettingsSection(
            title: '분류',
            children: [
              for (final category in settings.categories)
                _CategoryTile(
                  category: category,
                  onDelete: category.locked
                      ? null
                      : () => _deleteCategory(settings, category),
                ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _addCategory(settings),
                  icon: const Icon(Icons.add),
                  label: const Text('분류 추가'),
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: 'AI',
            children: [
              Opacity(
                opacity: 0.45,
                child: IgnorePointer(
                  child: Column(
                    children: [
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.auto_awesome_outlined),
                        title: Text('AI 기능'),
                        subtitle: Text('개발 중입니다.'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: settings.aiEnabled,
                        title: const Text('Gemini 사용'),
                        onChanged: (_) {},
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: settings.blockSensitiveAi,
                        title: const Text('민감 문장 AI 차단'),
                        onChanged: (_) {},
                      ),
                      TextField(
                        controller: _apiKeyController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Gemini API 키',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: '백업',
            children: [
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
            ],
          ),
          _SettingsSection(
            title: '계정',
            children: [
              _GoogleDriveSyncSettings(
                email: _driveEmail,
                busy: _syncBusy,
                message: _syncMessage,
                onConnect: _connectGoogleDrive,
                onSyncNow: _syncGoogleDriveNow,
                onDisconnect: _logoutGoogleDrive,
                onDeleteAccount: _deleteAccount,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save(AppSettings settings) async {
    await ref.read(settingsRepositoryProvider).save(settings);
    ref.read(appSettingsProvider.notifier).state = settings;
    unawaited(
      ref.read(googleDriveSyncServiceProvider).syncNow().catchError((_) {}),
    );
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

  Future<void> _addCategory(AppSettings settings) async {
    final category = await _showCategoryDialog(context);
    if (category == null) {
      return;
    }
    final categories = [
      ...settings.categories.where((item) => item.id != category.id),
      category,
    ];
    await _save(
      settings.copyWith(categories: _normalizeCategories(categories)),
    );
  }

  Future<void> _deleteCategory(
    AppSettings settings,
    EventCategory category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('분류 삭제'),
        content: Text('"${category.label}" 분류를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final categories = settings.categories
        .where((item) => item.id != category.id)
        .toList();
    await _save(
      settings.copyWith(categories: _normalizeCategories(categories)),
    );
  }

  List<EventCategory> _normalizeCategories(List<EventCategory> categories) {
    final normalized = categories
        .where((category) => category.id != EventCategory.holiday.id)
        .toList();
    normalized.add(EventCategory.holiday);
    return normalized;
  }

  Future<void> _connectGoogleDrive() async {
    setState(() {
      _syncBusy = true;
      _syncMessage = '';
    });
    try {
      final account = await ref
          .read(googleDriveAuthServiceProvider)
          .signIn(forceAccountSelection: true);
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
        _driveEmail = account?.email;
        _syncMessage = 'Google 계정 로그인이 완료되었습니다.';
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() => _syncMessage = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _syncBusy = false);
      }
    }
  }

  Future<void> _syncGoogleDriveNow() async {
    setState(() {
      _syncBusy = true;
      _syncMessage = '';
    });
    try {
      await ref
          .read(googleDriveSyncServiceProvider)
          .syncNow(promptIfNecessary: true);
      if (mounted) {
        ref.read(appSettingsProvider.notifier).state = ref
            .read(settingsRepositoryProvider)
            .load();
        setState(() => _syncMessage = '계정 동기화 완료');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _syncMessage = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _syncBusy = false);
      }
    }
  }

  Future<void> _logoutGoogleDrive() async {
    setState(() {
      _syncBusy = true;
      _syncMessage = '';
    });
    try {
      await ref.read(googleDriveAuthServiceProvider).signOut();
      final settings = ref
          .read(appSettingsProvider)
          .copyWith(onboardingCompleted: false);
      await ref.read(settingsRepositoryProvider).save(settings);
      ref.read(appSettingsProvider.notifier).state = settings;
      if (mounted) {
        setState(() {
          _driveEmail = null;
          _syncMessage = '로그아웃되었습니다.';
        });
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } finally {
      if (mounted) {
        setState(() => _syncBusy = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원탈퇴'),
        content: const Text(
          '계정 백업과 이 기기의 모든 일정, 설정을 삭제하고 로그인 화면으로 돌아갑니다. 이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _syncBusy = true;
      _syncMessage = '';
    });
    try {
      final events = await ref.read(eventRepositoryProvider).allEventsForSync();
      for (final event in events) {
        await ref
            .read(notificationServiceProvider)
            .cancelEventReminder(event.id);
      }
      await ref.read(notificationServiceProvider).cancelMorningBriefing();
      await ref
          .read(googleDriveSyncServiceProvider)
          .deleteCloudBackup(promptIfNecessary: true);
      await ref.read(eventRepositoryProvider).clearAll();
      await ref.read(settingsRepositoryProvider).resetAll();
      await ref.read(googleDriveAuthServiceProvider).signOut();
      ref.read(appSettingsProvider.notifier).state = const AppSettings();
      if (mounted) {
        setState(() {
          _driveEmail = null;
          _syncMessage = '회원탈퇴가 완료되었습니다.';
        });
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _syncMessage = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _syncBusy = false);
      }
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xffedf0f5)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetMinutesTile extends StatelessWidget {
  const _PresetMinutesTile({
    required this.title,
    required this.value,
    required this.presets,
    required this.onChanged,
    required this.onCustom,
  });

  final String title;
  final int value;
  final List<int> presets;
  final ValueChanged<int> onChanged;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final selectedValue = presets.contains(value) ? value : -1;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(_minutesLabel(value)),
      trailing: DropdownButton<int>(
        value: selectedValue,
        items: [
          for (final preset in presets)
            DropdownMenuItem(value: preset, child: Text(_minutesLabel(preset))),
          const DropdownMenuItem(value: -1, child: Text('직접 입력')),
        ],
        onChanged: (next) {
          if (next == null) {
            return;
          }
          if (next == -1) {
            onCustom();
          } else {
            onChanged(next);
          }
        },
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.title,
    required this.subtitle,
    required this.hour,
    required this.minute,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final int hour;
  final int minute;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(hour: hour, minute: minute);
    final label = _timeLabel(hour, minute);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text('$subtitle · $label'),
      trailing: IconButton(
        tooltip: '시간 선택',
        onPressed: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: time,
          );
          if (picked != null) {
            onChanged(picked);
          }
        },
        icon: const Icon(Icons.schedule),
      ),
    );
  }
}

class _DdayOffsetsTile extends StatelessWidget {
  const _DdayOffsetsTile({
    required this.offsets,
    required this.onChanged,
    required this.onCustom,
  });

  final List<int> offsets;
  final ValueChanged<List<int>> onChanged;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final selected = offsets.toSet();
    const presets = [-30, -14, -7, -3, -1, 0];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('D-day 알림'),
          const SizedBox(height: 4),
          Text(
            'D-day 표시가 켜진 일정에 적용합니다.',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final offset in presets)
                FilterChip(
                  label: Text(_ddayLabel(offset)),
                  selected: selected.contains(offset),
                  onSelected: (checked) {
                    final next = {...selected};
                    if (checked) {
                      next.add(offset);
                    } else {
                      next.remove(offset);
                    }
                    onChanged(next.toList()..sort());
                  },
                ),
              ActionChip(label: const Text('직접 입력'), onPressed: onCustom),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onDelete});

  final EventCategory category;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: Color(category.colorValue),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(category.label),
      subtitle: Text(category.locked ? '삭제 불가' : '사용자 분류'),
      trailing: IconButton(
        tooltip: category.locked ? '삭제 불가' : '분류 삭제',
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }
}

class _GoogleDriveSyncSettings extends StatelessWidget {
  const _GoogleDriveSyncSettings({
    required this.email,
    required this.busy,
    required this.message,
    required this.onConnect,
    required this.onSyncNow,
    required this.onDisconnect,
    required this.onDeleteAccount,
  });

  final String? email;
  final bool busy;
  final String message;
  final VoidCallback onConnect;
  final VoidCallback onSyncNow;
  final VoidCallback onDisconnect;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final connected = email != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(connected ? email! : 'Google 계정 로그인이 필요'),
          subtitle: Text(
            connected
                ? '이 Google 계정으로 모든 기기의 일정을 자동 백업하고 복원합니다.'
                : 'Google 계정으로 로그인해야 Daily를 사용할 수 있습니다.',
          ),
        ),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : (connected ? onSyncNow : onConnect),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(connected ? Icons.sync : Icons.login),
                label: Text(connected ? '지금 동기화' : 'Google로 로그인'),
              ),
            ),
            if (connected) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: busy ? null : onDisconnect,
                child: const Text('로그아웃'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy ? null : onDeleteAccount,
          icon: const Icon(Icons.person_remove_outlined),
          label: const Text('회원탈퇴'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
          ),
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(message, style: Theme.of(context).textTheme.labelMedium),
        ],
      ],
    );
  }
}

Future<EventCategory?> _showCategoryDialog(BuildContext context) async {
  final controller = TextEditingController();
  var selectedColor = _SettingsPageState._categoryColors.first;
  final category = await showDialog<EventCategory>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('분류 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            const SizedBox(height: 14),
            Text('색상', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final colorValue in _SettingsPageState._categoryColors)
                  ChoiceChip(
                    selected: selectedColor == colorValue,
                    label: const SizedBox.shrink(),
                    avatar: CircleAvatar(
                      radius: 8,
                      backgroundColor: Color(colorValue),
                    ),
                    onSelected: (_) =>
                        setState(() => selectedColor = colorValue),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final label = controller.text.trim();
              if (label.isEmpty) {
                return;
              }
              Navigator.of(context).pop(
                EventCategory.custom(label: label, colorValue: selectedColor),
              );
            },
            child: const Text('추가'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return category;
}

Future<int?> _showNumberDialog({
  required BuildContext context,
  required String title,
  required String label,
  required int initialValue,
}) async {
  final controller = TextEditingController(text: '$initialValue');
  final result = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            final value = int.tryParse(controller.text.trim());
            Navigator.of(context).pop(value);
          },
          child: const Text('적용'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

String _minutesLabel(int minutes) {
  if (minutes == 0) {
    return '정시';
  }
  if (minutes < 60) {
    return '$minutes분 전';
  }
  if (minutes % 1440 == 0) {
    return '${minutes ~/ 1440}일 전';
  }
  if (minutes % 60 == 0) {
    return '${minutes ~/ 60}시간 전';
  }
  return '$minutes분 전';
}

String _ddayLabel(int offset) {
  if (offset == 0) {
    return 'D-day';
  }
  return offset < 0 ? 'D$offset' : 'D+$offset';
}

String _timeLabel(int hour, int minute) {
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
