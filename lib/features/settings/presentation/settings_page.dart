import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/apple_account.dart';
import '../../../core/auth/apple_sign_in_service.dart';
import '../../../core/auth/daily_account.dart';
import '../../../core/auth/google_account.dart';
import '../../../core/di/app_providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sync/google_drive_auth_service.dart';
import '../../../core/sync/google_drive_sync_service.dart';
import '../../events/domain/calendar_event.dart';
import '../../events/domain/event_category.dart';

const _fallbackAppVersion = '2.5.14';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  static const _accountActionTimeout = Duration(seconds: 10);
  static const _logoutAccountReserve = Duration(seconds: 3);
  static const _resetNotificationCleanupTimeout = Duration(seconds: 3);

  final _apiKeyController = TextEditingController();
  late final Future<_AppVersionInfo> _appVersionInfo;
  var _syncMessage = '';
  var _syncBusy = false;
  var _appleMessage = '';
  var _appleBusy = false;
  var _notificationMessage = '';
  var _notificationBusy = false;
  String? _driveEmail;
  AppleAccount? _appleAccount;
  DailyAccount? _dailyAccount;
  var _googleDriveConnectAttempt = 0;
  int? _activeGoogleDriveConnectAttempt;

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
    _appVersionInfo = _loadAppVersionInfo();
    Future.microtask(() async {
      final key = await ref.read(settingsRepositoryProvider).geminiApiKey();
      final settingsRepository = ref.read(settingsRepositoryProvider);
      String? driveEmail;
      AppleAccount? appleAccount;
      var dailyAccount = settingsRepository.dailyAccount();
      try {
        final driveAccount = await ref
            .read(googleDriveAuthServiceProvider)
            .restorePreviousSignIn();
        if (driveAccount != null &&
            (dailyAccount?.googleAccount == null &&
                !settingsRepository.hasStoredDailyAccount)) {
          await settingsRepository.saveGoogleAccount(
            GoogleAccount(
              email: driveAccount.email,
              displayName: driveAccount.displayName,
            ),
          );
          dailyAccount = settingsRepository.dailyAccount();
        }
        if (driveAccount != null &&
            _matchesLinkedGoogleAccount(dailyAccount, driveAccount.email)) {
          driveEmail = driveAccount.email;
        }
      } on Object {
        driveEmail = null;
      }
      try {
        appleAccount = await ref
            .read(appleSignInServiceProvider)
            .refreshCurrentAccount();
      } on Object {
        appleAccount = ref.read(appleSignInServiceProvider).currentAccount;
      }
      if (mounted) {
        _apiKeyController.text = key ?? '';
        setState(() {
          _driveEmail = driveEmail;
          _appleAccount = appleAccount;
          _dailyAccount = settingsRepository.dailyAccount();
        });
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
    final appleSignInService = ref.watch(appleSignInServiceProvider);
    final account = _dailyAccount;
    final appleAccount = account?.appleAccount ?? _appleAccount;
    final hasAccountConnection = account?.hasProviders ?? false;
    final accountBusy = _appleBusy || _syncBusy;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          _SettingsSection(
            title: '알림',
            children: [
              _NotificationTestTile(
                message: _notificationMessage,
                busy: _notificationBusy,
                onPressed: _testNotification,
              ),
              if (_notificationMessage.contains('차단')) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _openNotificationSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('시스템 알림 설정 열기'),
                  ),
                ),
              ],
              const Divider(height: 1),
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
                use24HourTime: settings.use24HourTime,
                onChanged: (time) => _save(
                  settings.copyWith(
                    allDayReminderHour: time.hour,
                    allDayReminderMinute: time.minute,
                  ),
                ),
              ),
              const Divider(height: 1),
              _TimeFormatTile(
                use24HourTime: settings.use24HourTime,
                onChanged: (value) =>
                    _save(settings.copyWith(use24HourTime: value)),
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
                  use24HourTime: settings.use24HourTime,
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
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('기본 보기'),
                subtitle: const Text('앱을 열었을 때 먼저 보여줄 달력 보기'),
                trailing: DropdownButton<CalendarViewMode>(
                  value: settings.defaultCalendarView,
                  items: CalendarViewMode.values
                      .map(
                        (mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(mode.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _save(settings.copyWith(defaultCalendarView: value));
                      ref.read(calendarViewModeProvider.notifier).state = value;
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('월간 일정 표시 밀도'),
                subtitle: const Text('날짜 칸 안에 표시할 일정 수를 조절합니다.'),
                trailing: DropdownButton<CalendarDensity>(
                  value: settings.calendarDensity,
                  items: CalendarDensity.values
                      .map(
                        (density) => DropdownMenuItem(
                          value: density,
                          child: Text(density.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _save(settings.copyWith(calendarDensity: value));
                    }
                  },
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: '개인정보',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.hideSensitiveEvents,
                title: const Text('민감 일정 제목 숨김'),
                subtitle: const Text('달력과 상세 화면에서 민감 일정을 비공개로 표시합니다.'),
                onChanged: (value) =>
                    _save(settings.copyWith(hideSensitiveEvents: value)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.hideSensitiveNotifications,
                title: const Text('알림에서 민감 일정 숨김'),
                subtitle: const Text('민감 일정 알림 제목을 비공개로 표시합니다.'),
                onChanged: (value) async {
                  await _save(
                    settings.copyWith(hideSensitiveNotifications: value),
                  );
                  await _rescheduleNotifications();
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.appLockEnabled,
                title: const Text('앱 잠금'),
                subtitle: const Text('앱 실행 시 PIN을 확인합니다.'),
                onChanged: (value) => value
                    ? _enableAppLock(settings)
                    : _disableAppLock(settings),
              ),
            ],
          ),
          _SettingsSection(
            title: '분류',
            children: [
              for (final category in settings.categories)
                _CategoryTile(
                  category: category,
                  onEdit: category.locked
                      ? null
                      : () => _editCategory(settings, category),
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
            title: '계정',
            children: [
              _DailyAccountStatus(account: account),
              const Divider(height: 1),
              if (appleSignInService.isSupportedPlatform) ...[
                _AppleSignInSettings(
                  account: appleAccount,
                  busy: _appleBusy,
                  message: _appleMessage,
                  onSignIn: _connectApple,
                ),
                const Divider(height: 1),
              ],
              _SyncStatusTile(
                notifier: ref
                    .watch(googleDriveSyncServiceProvider)
                    .statusNotifier,
              ),
              const Divider(height: 1),
              _GoogleDriveSyncSettings(
                email: _driveEmail,
                busy: _syncBusy,
                message: _syncMessage,
                onConnect: _connectGoogleDrive,
                onSyncNow: _syncGoogleDriveNow,
                canCancelConnection: _canCancelGoogleDriveConnection,
                onCancelConnection: _cancelGoogleDriveSignIn,
                onDeleteAccount: _deleteAccount,
              ),
              if (hasAccountConnection) ...[
                const SizedBox(height: 8),
                _AccountLogoutButton(
                  busy: accountBusy,
                  onPressed: _logoutAccount,
                ),
              ],
            ],
          ),
          _SettingsSection(
            title: '앱 정보',
            children: [_AppVersionTile(versionInfo: _appVersionInfo)],
          ),
        ],
      ),
    );
  }

  Future<_AppVersionInfo> _loadAppVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return _AppVersionInfo(
        version: info.version.isEmpty ? _fallbackAppVersion : info.version,
        packageName: info.packageName,
      );
    } on Object {
      return const _AppVersionInfo(version: _fallbackAppVersion);
    }
  }

  Future<void> _connectApple() async {
    setState(() {
      _appleBusy = true;
      _appleMessage = 'Apple 로그인 창을 여는 중입니다.';
    });
    try {
      final account = await ref.read(appleSignInServiceProvider).signIn();
      if (!mounted) {
        return;
      }
      if (account == null) {
        setState(() => _appleMessage = 'Apple 로그인이 취소되었습니다.');
        return;
      }
      setState(() {
        _appleAccount = account;
        _dailyAccount = ref.read(settingsRepositoryProvider).dailyAccount();
        _appleMessage = 'Apple 로그인이 완료되었습니다.';
      });
      final restoredGoogleSync = await _restoreLinkedGoogleDriveSync();
      if (mounted) {
        setState(() {
          _appleMessage = restoredGoogleSync
              ? 'Apple 로그인이 완료되었습니다. 연결된 Google Drive 동기화를 복원했습니다.'
              : 'Apple 로그인이 완료되었습니다.';
        });
      }
    } on AppleSignInException catch (error) {
      if (mounted) {
        setState(() => _appleMessage = error.message);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _appleMessage = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _appleBusy = false);
      }
    }
  }

  Future<void> _save(AppSettings settings) async {
    await ref.read(settingsRepositoryProvider).save(settings);
    ref.read(appSettingsProvider.notifier).state = settings;
    unawaited(
      ref.read(googleDriveSyncServiceProvider).backupNow().catchError((_) {}),
    );
  }

  Future<void> _enableAppLock(AppSettings settings) async {
    final pin = await _showPinDialog(
      context: context,
      title: '앱 잠금 PIN 설정',
      label: '4자리 이상 PIN',
    );
    if (pin == null) {
      return;
    }
    if (pin.length < 4) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PIN은 4자리 이상이어야 합니다.')));
      }
      return;
    }
    await ref.read(settingsRepositoryProvider).saveAppLockPin(pin);
    await _save(settings.copyWith(appLockEnabled: true));
  }

  Future<void> _disableAppLock(AppSettings settings) async {
    await ref.read(settingsRepositoryProvider).deleteAppLockPin();
    await _save(settings.copyWith(appLockEnabled: false));
  }

  Future<void> _rescheduleNotifications() async {
    final events = await ref.read(eventRepositoryProvider).allEventsForSync();
    for (final event in events.where((event) => event.deletedAt == null)) {
      await ref
          .read(notificationServiceProvider)
          .cancelEventReminder(
            event.id,
            reminderMinutesBeforeList: event.reminderMinutesBeforeList,
          );
      await ref.read(notificationServiceProvider).scheduleEventReminder(event);
    }
  }

  Future<void> _testNotification() async {
    setState(() {
      _notificationBusy = true;
      _notificationMessage = '알림 상태 확인 중입니다.';
    });
    try {
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.showTestNotification();
      final summary = await notificationService.permissionSummary();
      if (!mounted) {
        return;
      }
      setState(() {
        _notificationMessage = '테스트 알림을 보냈습니다. $summary';
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() => _notificationMessage = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _notificationBusy = false);
      }
    }
  }

  Future<void> _openNotificationSettings() async {
    final urls = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => [Uri.parse('app-settings:')],
      TargetPlatform.macOS => [
        Uri.parse(
          'x-apple.systempreferences:com.apple.Notifications-Settings.extension',
        ),
        Uri.parse(
          'x-apple.systempreferences:com.apple.preference.notifications',
        ),
      ],
      TargetPlatform.windows => [Uri.parse('ms-settings:notifications')],
      _ => <Uri>[],
    };

    if (urls.isEmpty) {
      setState(() {
        _notificationMessage = 'Android에서는 시스템 설정 > 앱 > Daily > 알림에서 허용을 켜세요.';
      });
      return;
    }

    for (final url in urls) {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) {
        return;
      }
    }

    if (mounted) {
      setState(() {
        _notificationMessage = '시스템 알림 설정을 열 수 없습니다. OS 설정에서 Daily 알림을 허용하세요.';
      });
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

  Future<void> _editCategory(
    AppSettings settings,
    EventCategory category,
  ) async {
    final updatedCategory = await _showCategoryDialog(
      context,
      initialCategory: category,
    );
    if (updatedCategory == null) {
      return;
    }
    final categories = settings.categories
        .map((item) => item.id == category.id ? updatedCategory : item)
        .toList();
    final hiddenCategoryIds = settings.hiddenCategoryIds
        .map((id) => id == category.id ? updatedCategory.id : id)
        .toSet()
        .toList();
    await _save(
      settings.copyWith(
        categories: _normalizeCategories(categories),
        hiddenCategoryIds: hiddenCategoryIds,
      ),
    );
    await ref
        .read(eventCommandServiceProvider)
        .updateCategoryUsage(previous: category, updated: updatedCategory);
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
    final attempt = ++_googleDriveConnectAttempt;
    _activeGoogleDriveConnectAttempt = attempt;
    setState(() {
      _syncBusy = true;
      _syncMessage = '';
    });
    try {
      final authService = ref.read(googleDriveAuthServiceProvider);
      final account = await authService.signIn(forceAccountSelection: true);
      if (!_isCurrentGoogleDriveConnectAttempt(attempt)) {
        return;
      }
      if (account == null) {
        throw const GoogleDriveAuthException('Google 로그인이 취소되었습니다.');
      }
      final headers = await authService.authorizationHeaders(
        promptIfNecessary: true,
      );
      if (!_isCurrentGoogleDriveConnectAttempt(attempt)) {
        return;
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
      if (!_isCurrentGoogleDriveConnectAttempt(attempt)) {
        return;
      }
      await syncService.syncPendingChangesNow(
        promptIfNecessary: false,
        restoreAfterBackup: true,
      );
      if (!_isCurrentGoogleDriveConnectAttempt(attempt)) {
        return;
      }
      if (!mounted) {
        return;
      }
      ref.read(appSettingsProvider.notifier).state = ref
          .read(settingsRepositoryProvider)
          .load();
      setState(() {
        _driveEmail = account.email;
        _dailyAccount = ref.read(settingsRepositoryProvider).dailyAccount();
        _syncMessage = 'Google Drive 연결이 완료되었습니다.';
      });
    } on Object catch (error) {
      if (mounted && _isCurrentGoogleDriveConnectAttempt(attempt)) {
        setState(() => _syncMessage = _googleAccountErrorMessage(error));
      }
    } finally {
      if (mounted && _isCurrentGoogleDriveConnectAttempt(attempt)) {
        setState(() {
          _activeGoogleDriveConnectAttempt = null;
          _syncBusy = false;
        });
      }
    }
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
      final account = await authService.restorePreviousSignIn();
      if (account == null || !_sameEmail(account.email, linkedGoogle.email)) {
        return false;
      }
      final headers = await authService.authorizationHeaders();
      if (headers == null) {
        return false;
      }
      final syncService = ref.read(googleDriveSyncServiceProvider);
      await syncService.startListeningOnly(flushPendingChanges: false);
      await syncService.syncPendingChangesNow(restoreAfterBackup: true);
      if (mounted) {
        setState(() => _driveEmail = account.email);
      }
      return true;
    } on Object {
      return false;
    }
  }

  bool _matchesLinkedGoogleAccount(DailyAccount? account, String email) {
    final linkedEmail = account?.googleAccount?.email;
    return linkedEmail != null && _sameEmail(linkedEmail, email);
  }

  bool _sameEmail(String left, String right) =>
      left.trim().toLowerCase() == right.trim().toLowerCase();

  bool _isCurrentGoogleDriveConnectAttempt(int attempt) {
    return _googleDriveConnectAttempt == attempt;
  }

  bool get _canCancelGoogleDriveConnection {
    if (!_syncBusy || _activeGoogleDriveConnectAttempt == null) {
      return false;
    }
    return ref
        .read(googleDriveAuthServiceProvider)
        .canCancelPendingSignInOnResume;
  }

  void _cancelGoogleDriveSignIn() {
    final attempt = _activeGoogleDriveConnectAttempt;
    if (attempt == null || !_isCurrentGoogleDriveConnectAttempt(attempt)) {
      return;
    }
    final authService = ref.read(googleDriveAuthServiceProvider);
    if (!authService.canCancelPendingSignInOnResume) {
      return;
    }
    authService.cancelPendingSignIn();
    _googleDriveConnectAttempt += 1;
    if (mounted) {
      setState(() {
        _activeGoogleDriveConnectAttempt = null;
        _syncBusy = false;
        _syncMessage = 'Google Drive 연결이 취소되었습니다. 다시 연결할 수 있습니다.';
      });
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
        setState(() => _syncMessage = 'Google Drive 동기화 완료');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _syncMessage = _googleAccountErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _syncBusy = false);
      }
    }
  }

  Future<void> _logoutAccount() async {
    setState(() {
      _syncBusy = true;
      _syncMessage = '';
      _appleMessage = '';
    });
    try {
      await _tryFlushPendingBeforeLogout(Stopwatch()..start());
      if (mounted) {
        final updated = ref
            .read(appSettingsProvider)
            .copyWith(onboardingCompleted: false);
        await ref.read(settingsRepositoryProvider).save(updated);
        if (!mounted) {
          return;
        }
        setState(() {
          _driveEmail = null;
          _syncMessage = '로그아웃했습니다.';
        });
        ref.read(appSettingsProvider.notifier).state = updated;
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _syncMessage = _googleAccountErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _syncBusy = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final authService = ref.read(googleDriveAuthServiceProvider);
    final hasGoogleAccount =
        _driveEmail != null || authService.currentAccount != null;
    final hasSignedInAccount = hasGoogleAccount || _appleAccount != null;
    final title = hasSignedInAccount ? '회원탈퇴' : '로컬 데이터 초기화';
    final content = hasSignedInAccount
        ? 'Google Drive의 Daily 백업, 이 기기의 모든 일정과 설정, Apple/Google 로그인 정보를 삭제하고 시작 화면으로 돌아갑니다. 이 작업은 되돌릴 수 없습니다.'
        : '이 기기의 모든 일정과 설정을 삭제하고 시작 화면으로 돌아갑니다.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(hasSignedInAccount ? '회원탈퇴' : '초기화'),
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
      await _tryCancelNotificationsBeforeReset(events);
      if (hasGoogleAccount) {
        await ref
            .read(googleDriveSyncServiceProvider)
            .deleteCloudBackup(promptIfNecessary: true);
      }
      await ref.read(eventRepositoryProvider).clearAll();
      await ref.read(settingsRepositoryProvider).resetAll();
      if (hasGoogleAccount) {
        await authService.signOut();
      }
      await ref.read(appleSignInServiceProvider).signOut();
      ref.read(appSettingsProvider.notifier).state = const AppSettings();
      if (mounted) {
        setState(() {
          _driveEmail = null;
          _appleAccount = null;
          _syncMessage = hasSignedInAccount
              ? '회원탈퇴가 완료되었습니다.'
              : '로컬 데이터 초기화가 완료되었습니다.';
        });
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _syncMessage = _googleAccountErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _syncBusy = false);
      }
    }
  }

  Future<void> _tryCancelNotificationsBeforeReset(
    List<CalendarEvent> events,
  ) async {
    try {
      await Future<void>(() async {
        final notificationService = ref.read(notificationServiceProvider);
        for (final event in events) {
          await notificationService.cancelEventReminder(
            event.id,
            reminderMinutesBeforeList: event.reminderMinutesBeforeList,
          );
        }
        await notificationService.cancelMorningBriefing();
      }).timeout(_resetNotificationCleanupTimeout);
    } on Object {
      // Local data reset must not be blocked by OS notification permission,
      // signing, or notification-center state. Stale reminders are resynced or
      // cleared on the next successful notification initialization.
    }
  }

  Future<void> _tryFlushPendingBeforeLogout(Stopwatch stopwatch) async {
    final syncBudget =
        _accountActionTimeout - stopwatch.elapsed - _logoutAccountReserve;
    if (syncBudget <= Duration.zero) {
      return;
    }
    try {
      await ref
          .read(googleDriveSyncServiceProvider)
          .syncPendingChangesNow(promptIfNecessary: false)
          .timeout(syncBudget);
    } on Object {
      // Pending local changes keep their pending state and are retried later.
    }
  }

  String _googleAccountErrorMessage(Object error) {
    if (error is GoogleDriveAuthException) {
      return error.message;
    }
    if (error is GoogleDriveSyncException) {
      return error.message;
    }

    final text = error.toString().trim();
    if (text.isEmpty) {
      return '요청을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
    final lower = text.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network') ||
        lower.contains('timeoutexception')) {
      return '네트워크 연결을 확인한 뒤 다시 시도해 주세요.';
    }
    if (lower.contains('invalid_grant') ||
        lower.contains('invalid_token') ||
        text.contains('HTTP 401')) {
      return 'Google Drive 연결이 만료되었습니다. 다시 연결해 주세요.';
    }
    if (lower.contains('permission') ||
        lower.contains('insufficient') ||
        text.contains('HTTP 403')) {
      return 'Google Drive 권한이 부족합니다. 다시 연결해 권한을 승인해 주세요.';
    }
    if (text.contains('HTTP 429')) {
      return 'Google Drive 요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.';
    }
    if (RegExp(r'HTTP 5\d\d').hasMatch(text)) {
      return 'Google Drive 서버 응답이 불안정합니다. 잠시 후 다시 시도해 주세요.';
    }
    return text;
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
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xffedf0f5)),
          borderRadius: BorderRadius.circular(10),
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

class _AppVersionInfo {
  const _AppVersionInfo({required this.version, this.packageName = ''});

  final String version;
  final String packageName;
}

class _AppVersionTile extends StatelessWidget {
  const _AppVersionTile({required this.versionInfo});

  final Future<_AppVersionInfo> versionInfo;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppVersionInfo>(
      future: versionInfo,
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info?.version ?? '확인 중';
        final packageName = info?.packageName ?? '';
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline),
          title: const Text('Daily 버전'),
          subtitle: Text(
            packageName.isEmpty ? '버전 $version' : '버전 $version · $packageName',
          ),
        );
      },
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
    required this.use24HourTime,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final int hour;
  final int minute;
  final bool use24HourTime;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(hour: hour, minute: minute);
    final label = _timeLabel(hour, minute, use24HourTime: use24HourTime);
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
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(alwaysUse24HourFormat: use24HourTime),
                child: child ?? const SizedBox.shrink(),
              );
            },
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

class _TimeFormatTile extends StatelessWidget {
  const _TimeFormatTile({required this.use24HourTime, required this.onChanged});

  final bool use24HourTime;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('시간 표시 방식'),
                SizedBox(height: 2),
                Text(
                  '시간 선택 화면의 기본 표시 방식을 정합니다.',
                  style: TextStyle(fontSize: 12, color: Color(0xff64748b)),
                ),
              ],
            ),
          ),
          SegmentedButton<bool>(
            selected: {use24HourTime},
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              minimumSize: WidgetStateProperty.all(const Size(50, 34)),
            ),
            segments: const [
              ButtonSegment(value: false, label: Text('12h')),
              ButtonSegment(value: true, label: Text('24h')),
            ],
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ],
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

class _NotificationTestTile extends StatelessWidget {
  const _NotificationTestTile({
    required this.message,
    required this.busy,
    required this.onPressed,
  });

  final String message;
  final bool busy;
  final VoidCallback onPressed;

  static const _defaultMessage = '즉시 알림을 보내고 예약 상태를 확인합니다.';

  @override
  Widget build(BuildContext context) {
    final subtitle = message.isEmpty ? _defaultMessage : message;
    final button = FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('보내기'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 520) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('알림 테스트'),
            subtitle: Text(subtitle),
            trailing: button,
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('알림 테스트', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: button),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final EventCategory category;
  final VoidCallback? onEdit;
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
      subtitle: Text(category.locked ? '수정 불가' : '사용자 분류'),
      trailing: category.locked
          ? Tooltip(
              message: '수정 불가',
              child: Icon(
                Icons.lock_outline,
                color: Theme.of(context).disabledColor,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '분류 수정',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: '분류 삭제',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
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
    required this.canCancelConnection,
    required this.onCancelConnection,
    required this.onDeleteAccount,
  });

  final String? email;
  final bool busy;
  final String message;
  final VoidCallback onConnect;
  final VoidCallback onSyncNow;
  final bool canCancelConnection;
  final VoidCallback onCancelConnection;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final connected = email != null;
    final connecting = busy && !connected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.account_circle_outlined),
          title: const Text('Google 계정'),
          subtitle: Text(connected ? email! : 'Google 로그인 시 Daily 계정에 연결됩니다.'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cloud_sync_outlined),
          title: const Text('Google Drive 동기화'),
          subtitle: Text(
            connected
                ? '이 계정의 Google Drive AppData에 일정을 백업하고 복원합니다.'
                : 'Google 로그인 시 Drive AppData 권한도 함께 승인합니다.',
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
                    : Icon(connected ? Icons.sync : Icons.cloud_outlined),
                label: Text(
                  connecting
                      ? 'Google 연결 중'
                      : connected
                      ? '지금 동기화'
                      : 'Google로 계속',
                ),
              ),
            ),
          ],
        ),
        if (canCancelConnection) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onCancelConnection,
            icon: const Icon(Icons.close),
            label: const Text('연결 취소'),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy ? null : onDeleteAccount,
          icon: const Icon(Icons.person_remove_outlined),
          label: Text(connected ? '회원탈퇴' : '로컬 데이터 초기화'),
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

class _AppleSignInSettings extends StatelessWidget {
  const _AppleSignInSettings({
    required this.account,
    required this.busy,
    required this.message,
    required this.onSignIn,
  });

  final AppleAccount? account;
  final bool busy;
  final String message;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final connected = account != null;
    final title = connected
        ? account!.displayName ?? account!.email ?? 'Apple로 로그인됨'
        : 'Apple 로그인';
    final subtitle = connected
        ? [
            if (account!.email != null) account!.email!,
            'Daily 계정에 연결된 Apple 로그인입니다.',
          ].join('\n')
        : 'Apple 로그인만으로 Daily를 사용할 수 있습니다.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.apple),
          title: Text(title),
          subtitle: Text(subtitle),
        ),
        if (!connected)
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onSignIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.apple),
                  label: const Text('Apple로 계속'),
                ),
              ),
            ],
          ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(message, style: Theme.of(context).textTheme.labelMedium),
        ],
      ],
    );
  }
}

class _DailyAccountStatus extends StatelessWidget {
  const _DailyAccountStatus({required this.account});

  final DailyAccount? account;

  @override
  Widget build(BuildContext context) {
    final providers = [
      if (account?.appleAccount != null) 'Apple',
      if (account?.googleAccount != null) 'Google',
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.person_outline),
      title: const Text('Daily 계정'),
      subtitle: Text(
        providers.isEmpty
            ? 'Apple 또는 Google 계정을 연결할 수 있습니다.'
            : '${providers.join(' · ')} 로그인 연결됨',
      ),
    );
  }
}

class _AccountLogoutButton extends StatelessWidget {
  const _AccountLogoutButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.logout),
      label: const Text('로그아웃'),
    );
  }
}

class _SyncStatusTile extends StatelessWidget {
  const _SyncStatusTile({required this.notifier});

  final ValueNotifier<GoogleDriveSyncStatus> notifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GoogleDriveSyncStatus>(
      valueListenable: notifier,
      builder: (context, status, _) {
        final lastSyncedAt = status.lastSyncedAt;
        final error = status.error;
        final message = status.message;
        final syncing = status.syncing;
        final subtitle = [
          if (lastSyncedAt != null) '마지막 성공: ${_formatDateTime(lastSyncedAt)}',
          if (message.isNotEmpty) message,
          if (error != null && error.isNotEmpty) error,
        ].join('\n');
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(syncing ? Icons.sync : Icons.cloud_done_outlined),
          title: const Text('동기화 상태'),
          subtitle: Text(subtitle.isEmpty ? '아직 동기화 기록이 없습니다.' : subtitle),
        );
      },
    );
  }
}

Future<EventCategory?> _showCategoryDialog(
  BuildContext context, {
  EventCategory? initialCategory,
}) async {
  return showDialog<EventCategory>(
    context: context,
    builder: (context) => _CategoryDialog(initialCategory: initialCategory),
  );
}

Future<int?> _showNumberDialog({
  required BuildContext context,
  required String title,
  required String label,
  required int initialValue,
}) async {
  return showDialog<int>(
    context: context,
    builder: (context) =>
        _NumberDialog(title: title, label: label, initialValue: initialValue),
  );
}

Future<String?> _showPinDialog({
  required BuildContext context,
  required String title,
  required String label,
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) => _PinDialog(title: title, label: label),
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.initialCategory});

  final EventCategory? initialCategory;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _controller;
  late int _selectedColor;
  late final List<int> _colorValues;

  bool get _editing => widget.initialCategory != null;

  @override
  void initState() {
    super.initState();
    final initialCategory = widget.initialCategory;
    _controller = TextEditingController(text: initialCategory?.label ?? '');
    _selectedColor =
        initialCategory?.colorValue ?? _SettingsPageState._categoryColors.first;
    _colorValues = {
      _selectedColor,
      ..._SettingsPageState._categoryColors,
    }.toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? '분류 수정' : '분류 추가'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
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
                for (final colorValue in _colorValues)
                  ChoiceChip(
                    selected: _selectedColor == colorValue,
                    label: const SizedBox.shrink(),
                    avatar: CircleAvatar(
                      radius: 8,
                      backgroundColor: Color(colorValue),
                    ),
                    onSelected: (_) =>
                        setState(() => _selectedColor = colorValue),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            final label = _controller.text.trim();
            if (label.isEmpty) {
              return;
            }
            FocusManager.instance.primaryFocus?.unfocus();
            final initialCategory = widget.initialCategory;
            final nextCategory =
                initialCategory == null ||
                    (initialCategory.id != EventCategory.basic.id &&
                        initialCategory.id != EventCategory.holiday.id)
                ? EventCategory.custom(label: label, colorValue: _selectedColor)
                : initialCategory.copyWith(
                    label: label,
                    colorValue: _selectedColor,
                  );
            Navigator.of(context).pop(nextCategory);
          },
          child: Text(_editing ? '저장' : '추가'),
        ),
      ],
    );
  }
}

class _NumberDialog extends StatefulWidget {
  const _NumberDialog({
    required this.title,
    required this.label,
    required this.initialValue,
  });

  final String title;
  final String label;
  final int initialValue;

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialValue}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: widget.label),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            final value = int.tryParse(_controller.text.trim());
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop(value);
          },
          child: const Text('적용'),
        ),
      ],
    );
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title, required this.label});

  final String title;
  final String label;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: TextField(
          controller: _controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: widget.label),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: const Text('적용'),
        ),
      ],
    );
  }
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

String _timeLabel(int hour, int minute, {required bool use24HourTime}) {
  final paddedMinute = minute.toString().padLeft(2, '0');
  if (use24HourTime) {
    return '${hour.toString().padLeft(2, '0')}:$paddedMinute';
  }
  final period = hour < 12 ? 'AM' : 'PM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$period $displayHour:$paddedMinute';
}

String _formatDateTime(DateTime value) {
  return '${value.month}월 ${value.day}일 '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
