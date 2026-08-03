import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/apple_account.dart';
import '../../../core/auth/apple_sign_in_service.dart';
import '../../../core/auth/daily_account.dart';
import '../../../core/auth/google_account.dart';
import '../../../core/di/app_providers.dart';
import '../../../core/security/biometric_auth_service.dart';
import '../../../core/security/app_lock_privacy_service.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/support/bug_report_service.dart';
import '../../../core/sync/google_drive_auth_service.dart';
import '../../../core/sync/google_drive_sync_service.dart';
import '../../events/domain/calendar_event.dart';
import '../../events/domain/event_category.dart';
import 'calendar_import_page.dart';

const _fallbackAppVersion = '3.0.0';

enum _SettingsDestination { notifications, account }

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key}) : _destination = null;

  const SettingsPage._destination({required _SettingsDestination destination})
    : _destination = destination;

  final _SettingsDestination? _destination;

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
  var _deviceAuthenticationAvailable = false;
  var _biometricAuthenticationAvailable = false;
  AppleAccount? _appleAccount;
  GoogleDriveAccount? _googleDriveAccount;
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
      AppleAccount? appleAccount;
      GoogleDriveAccount? googleDriveAccount;
      var dailyAccount = settingsRepository.dailyAccount();
      try {
        googleDriveAccount = await ref
            .read(googleDriveAuthServiceProvider)
            .restorePreviousSignIn();
        if (googleDriveAccount != null) {
          final headers = await ref
              .read(googleDriveAuthServiceProvider)
              .authorizationHeaders();
          if (headers == null) {
            googleDriveAccount = null;
          }
        }
        if (googleDriveAccount != null &&
            (dailyAccount?.googleAccount == null &&
                !settingsRepository.hasStoredDailyAccount)) {
          await settingsRepository.saveGoogleAccount(
            GoogleAccount(
              email: googleDriveAccount.email,
              displayName: googleDriveAccount.displayName,
            ),
          );
          dailyAccount = settingsRepository.dailyAccount();
        }
      } on Object {
        // Settings still shows the saved provider connection if restoration fails.
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
          _appleAccount = appleAccount;
          _googleDriveAccount = googleDriveAccount;
          _dailyAccount = settingsRepository.dailyAccount();
        });
      }
    });
    Future.microtask(() async {
      final authentication = BiometricAuthService();
      final available = await authentication.isDeviceAuthenticationAvailable();
      final biometricsAvailable = defaultTargetPlatform == TargetPlatform.macOS
          ? await authentication.isBiometricsOrCompanionAvailable()
          : await authentication.isAvailable();
      if (mounted) {
        setState(() {
          _deviceAuthenticationAvailable = available;
          _biometricAuthenticationAvailable = biometricsAvailable;
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

    final pageTitle = switch (widget._destination) {
      _SettingsDestination.notifications => '알림 설정',
      _SettingsDestination.account => '계정 설정',
      null => '설정',
    };
    return Scaffold(
      appBar: AppBar(title: Text(pageTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          if (widget._destination == null)
            _SettingsSection(
              title: '설정',
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('알림'),
                  subtitle: const Text('일정 알림, 아침 브리핑, D-day 알림'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsPage._destination(
                        destination: _SettingsDestination.notifications,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('account-settings-navigation'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_circle_outlined),
                  title: const Text('계정'),
                  subtitle: const Text('Apple, Google, 동기화 및 계정 관리'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsPage._destination(
                        destination: _SettingsDestination.account,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (widget._destination == _SettingsDestination.notifications)
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
                _DefaultRemindersTile(
                  title: '기본 일정 알림',
                  values: settings.defaultReminderMinutesList,
                  presets: const [0, 10, 30, 60, 1440],
                  onChanged: (values) => _save(
                    settings.copyWith(defaultReminderMinutesList: values),
                  ),
                  onCustom: () async {
                    final value = await _showNumberDialog(
                      context: context,
                      title: '기본 알림 직접 입력',
                      label: '몇 분 전에 알릴까요?',
                      initialValue: settings.defaultReminderMinutes,
                    );
                    if (value != null && value >= 0) {
                      await _save(
                        settings.copyWith(
                          defaultReminderMinutesList: normalizeReminderMinutes([
                            ...settings.defaultReminderMinutesList,
                            value,
                          ]),
                        ),
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
          if (widget._destination == null)
            _SettingsSection(
              title: '화면',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          '테마',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: _ThreeWayCapsule<AppThemeMode>(
                          key: const ValueKey('app-theme-mode-slider'),
                          values: AppThemeMode.values,
                          selected: settings.themeMode,
                          labelFor: (mode) => mode.label,
                          onChanged: (mode) =>
                              _save(settings.copyWith(themeMode: mode)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          if (widget._destination == null)
            _SettingsSection(
              title: '달력',
              children: [
                if (defaultTargetPlatform == TargetPlatform.iOS ||
                    defaultTargetPlatform == TargetPlatform.android) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.move_to_inbox_outlined),
                    title: const Text('캘린더 데이터 옮기기'),
                    subtitle: Text(
                      defaultTargetPlatform == TargetPlatform.android
                          ? 'Samsung 캘린더 또는 Google 캘린더에서 가져옵니다.'
                          : 'Apple 캘린더 또는 Google 캘린더에서 가져옵니다.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CalendarImportPage(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('주 시작 요일'),
                  trailing: SizedBox(
                    width: 132,
                    child: _ThreeWayCapsule<bool>(
                      key: const ValueKey('week-start-toggle'),
                      values: const [false, true],
                      selected: settings.weekStartsOnMonday,
                      labelFor: (startsOnMonday) => startsOnMonday ? '월' : '일',
                      onChanged: (value) =>
                          _save(settings.copyWith(weekStartsOnMonday: value)),
                    ),
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
                if (defaultTargetPlatform == TargetPlatform.iOS ||
                    defaultTargetPlatform == TargetPlatform.macOS) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value:
                        settings.monthNavigationMode ==
                            MonthNavigationMode.vertical
                        ? false
                        : settings.showAdjacentMonthDates,
                    title: const Text('인접한 달 날짜 표시'),
                    subtitle: Text(
                      settings.monthNavigationMode ==
                              MonthNavigationMode.vertical
                          ? '상하 스크롤에서는 월 경계를 명확히 구분하기 위해 사용할 수 없습니다.'
                          : '월간 달력의 첫주와 마지막 주에 이전·다음 달을 표시합니다.',
                    ),
                    onChanged:
                        settings.monthNavigationMode ==
                            MonthNavigationMode.vertical
                        ? null
                        : (value) => _save(
                            settings.copyWith(showAdjacentMonthDates: value),
                          ),
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('월간 이동 방식'),
                  trailing: SizedBox(
                    width: 224,
                    child: _ThreeWayCapsule<MonthNavigationMode>(
                      key: const ValueKey('month-navigation-mode-slider'),
                      values: MonthNavigationMode.values,
                      selected: settings.monthNavigationMode,
                      labelFor: (mode) => mode.label,
                      onChanged: (value) => _save(
                        settings.copyWith(
                          monthNavigationMode: value,
                          showAdjacentMonthDates:
                              value == MonthNavigationMode.vertical
                              ? false
                              : settings.showAdjacentMonthDates,
                        ),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('기본 보기'),
                  subtitle: const Text('앱을 열었을 때 먼저 보여줄 달력 보기'),
                  trailing: SizedBox(
                    width: 188,
                    child: _ThreeWayCapsule<CalendarViewMode>(
                      key: const ValueKey('default-calendar-view-slider'),
                      values: CalendarViewMode.values,
                      selected: settings.defaultCalendarView,
                      labelFor: (mode) => mode.label,
                      onChanged: (value) {
                        _save(settings.copyWith(defaultCalendarView: value));
                        ref.read(calendarViewModeProvider.notifier).state =
                            value;
                      },
                    ),
                  ),
                ),
                const Divider(height: 1),
                _AppTextSizeSlider(
                  textSize: settings.appTextSize,
                  onChanged: (value) =>
                      _save(settings.copyWith(appTextSize: value)),
                ),
              ],
            ),
          if (widget._destination == null)
            _SettingsSection(
              title: '개인정보',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.appLockEnabled,
                  title: const Text('앱 잠금'),
                  subtitle: Text(
                    settings.appLockEnabled
                        ? '앱 실행 시 ${settings.appLockMethod.label}으로 확인합니다.'
                        : '앱을 다시 열 때 사용자를 확인합니다.',
                  ),
                  onChanged: (value) => value
                      ? _enableAppLock(settings)
                      : _disableAppLock(settings),
                ),
                if (settings.appLockEnabled) ...[
                  const Divider(height: 1),
                  _AppLockMethodSlider(
                    method: settings.appLockMethod,
                    systemAuthenticationAvailable:
                        _deviceAuthenticationAvailable,
                    onChanged: (method) =>
                        _changeAppLockMethod(settings, method),
                  ),
                  if (settings.appLockMethod == AppLockMethod.appPin) ...[
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: settings.appLockBiometricsEnabled,
                      title: const Text('생체인식 잠금 해제'),
                      subtitle: Text(
                        _biometricAuthenticationAvailable
                            ? defaultTargetPlatform == TargetPlatform.macOS
                                  ? 'PIN 대신 Touch ID 또는 Apple Watch로 잠금을 해제할 수 있습니다.'
                                  : 'PIN 대신 Face ID 또는 Touch ID로 잠금을 해제할 수 있습니다.'
                            : '이 기기에서 사용할 수 있는 생체인식이 없습니다.',
                      ),
                      onChanged: _biometricAuthenticationAvailable
                          ? (value) =>
                                _changePinBiometricUnlock(settings, value)
                          : null,
                    ),
                  ],
                ],
              ],
            ),
          if (widget._destination == null)
            _SettingsSection(
              title: '분류',
              children: [
                for (final category in settings.categories)
                  _CategoryTile(
                    category: category,
                    visible: !settings.hiddenCategoryIds.contains(category.id),
                    onVisibilityChanged: (visible) =>
                        _setCategoryVisible(settings, category, visible),
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
          if (widget._destination == null)
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
          if (widget._destination == _SettingsDestination.account)
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
                    onDisconnect: _disconnectApple,
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
                  email: account?.googleAccount?.email,
                  sessionConnected: _googleDriveAccount != null,
                  busy: _syncBusy,
                  message: _syncMessage,
                  onConnect: _connectGoogleDrive,
                  onBackup: _backupGoogleDriveNow,
                  onRestore: _restoreGoogleDriveNow,
                  canCancelConnection: _canCancelGoogleDriveConnection,
                  onCancelConnection: _cancelGoogleDriveSignIn,
                  onDisconnect: _disconnectGoogle,
                  hasDailyAccount: hasAccountConnection,
                  onDeleteDailyAccount: _deleteAccount,
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
          if (widget._destination == null)
            _SettingsSection(
              title: '앱 정보',
              children: [
                _AppVersionTile(
                  versionInfo: _appVersionInfo,
                  onDoubleTap: _openGithubRepository,
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('버그 제보'),
                  subtitle: const Text('GitHub 제보 양식을 기본 브라우저에서 엽니다.'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: _reportBug,
                ),
              ],
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
        buildNumber: info.version.isEmpty ? _fallbackAppVersion : info.version,
        packageName: info.packageName,
      );
    } on Object {
      return const _AppVersionInfo(
        version: _fallbackAppVersion,
        buildNumber: _fallbackAppVersion,
      );
    }
  }

  Future<void> _openGithubRepository() async {
    const repositoryUrl = 'https://github.com/littlebit0/Daily';
    final opened = await launchUrl(
      Uri.parse(repositoryUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GitHub Repository를 열 수 없습니다.')),
      );
    }
  }

  Future<void> _reportBug() async {
    final info = await _appVersionInfo;
    final environment = BugReportEnvironment(
      version: info.version,
      buildNumber: info.buildNumber,
      platform: _platformName(defaultTargetPlatform),
      osVersion: Platform.operatingSystemVersion,
    );
    final opened = await BugReportService.open(environment);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('버그 제보 페이지를 열 수 없습니다. 잠시 후 다시 시도하세요.')),
      );
    }
  }

  String _platformName(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
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

  Future<void> _disconnectApple() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apple 연동 해지'),
        content: const Text(
          'Apple 계정 연결을 해제할까요? iCloud 저장 기능은 아직 제공되지 않아 저장 내용 초기화는 사용할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          const Tooltip(
            message: 'iCloud 저장 기능이 추가된 후 사용할 수 있습니다.',
            child: FilledButton(onPressed: null, child: Text('저장 내용 초기화')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('연동 해지'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _appleBusy = true;
      _appleMessage = '';
    });
    try {
      await ref.read(settingsRepositoryProvider).deleteAppleAccount();
      if (mounted) {
        setState(() {
          _appleAccount = null;
          _dailyAccount = ref.read(settingsRepositoryProvider).dailyAccount();
          _appleMessage = 'Apple 연동을 해지했습니다.';
        });
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

  Future<void> _save(AppSettings settings, {bool backup = true}) async {
    await ref.read(settingsRepositoryProvider).save(settings);
    ref.read(appSettingsProvider.notifier).state = settings;
    if (backup) {
      unawaited(
        ref.read(googleDriveSyncServiceProvider).backupNow().catchError((_) {}),
      );
    }
  }

  Future<void> _enableAppLock(AppSettings settings) async {
    final method = await _selectLockMethod(settings.appLockMethod);
    if (method == null || !await _prepareLockMethod(method)) {
      return;
    }
    await _save(
      settings.copyWith(
        appLockEnabled: true,
        appLockMethod: method,
        appLockBiometricsEnabled: false,
      ),
    );
  }

  Future<void> _disableAppLock(AppSettings settings) async {
    final repository = ref.read(settingsRepositoryProvider);
    final confirmed = await _confirmCurrentLockMethod(settings.appLockMethod);
    if (confirmed != true) {
      return;
    }
    if (settings.appLockMethod == AppLockMethod.appPin) {
      await repository.deleteAppLockPin();
    }
    await _save(
      settings.copyWith(appLockEnabled: false, appLockBiometricsEnabled: false),
    );
  }

  Future<void> _changeAppLockMethod(
    AppSettings settings,
    AppLockMethod method,
  ) async {
    if (method == settings.appLockMethod) {
      return;
    }
    if (!await _confirmCurrentLockMethod(settings.appLockMethod)) {
      return;
    }
    if (!await _prepareLockMethod(method)) {
      return;
    }
    final repository = ref.read(settingsRepositoryProvider);
    if (settings.appLockMethod == AppLockMethod.appPin &&
        method != AppLockMethod.appPin) {
      await repository.deleteAppLockPin();
    }
    await _save(
      settings.copyWith(appLockMethod: method, appLockBiometricsEnabled: false),
    );
  }

  Future<bool> _prepareLockMethod(AppLockMethod method) async {
    switch (method) {
      case AppLockMethod.noPin:
        return true;
      case AppLockMethod.appPin:
        final repository = ref.read(settingsRepositoryProvider);
        if (await repository.appLockPinLength() != null) {
          return true;
        }
        if (!mounted) {
          return false;
        }
        final pin = await _showPinSetupDialog(
          context: context,
          title: '앱 잠금 PIN 설정',
        );
        if (pin == null) {
          return false;
        }
        await repository.saveAppLockPin(pin);
        return true;
      case AppLockMethod.system:
        if (_deviceAuthenticationAvailable) {
          return AppLockPrivacyService().duringConfigurationAuthentication(
            () => BiometricAuthService().authenticate(
              localizedReason: '시스템 잠금 방식으로 Daily 앱 잠금을 활성화합니다.',
              allowDeviceCredentials: true,
            ),
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이 기기에서 시스템 잠금 인증을 사용할 수 없습니다.')),
          );
        }
        return false;
    }
  }

  Future<AppLockMethod?> _selectLockMethod(AppLockMethod initialMethod) async {
    if (!mounted) {
      return null;
    }
    return showDialog<AppLockMethod>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('잠금 방식 선택'),
        children: [
          for (final method in AppLockMethod.values)
            SimpleDialogOption(
              onPressed:
                  method == AppLockMethod.system &&
                      !_deviceAuthenticationAvailable
                  ? null
                  : () => Navigator.of(context).pop(method),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  method == initialMethod
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(method.label),
                subtitle: Text(_lockMethodDescription(method)),
                enabled:
                    method != AppLockMethod.system ||
                    _deviceAuthenticationAvailable,
              ),
            ),
        ],
      ),
    );
  }

  String _lockMethodDescription(AppLockMethod method) => switch (method) {
    AppLockMethod.noPin => '앱을 벗어난 동안 화면만 가리고 복귀하면 자동으로 해제합니다.',
    AppLockMethod.appPin => 'Daily 전용 PIN으로 잠그며 생체인식을 선택해서 함께 사용할 수 있습니다.',
    AppLockMethod.system => '기기의 Face ID, Touch ID 또는 시스템 비밀번호로 인증합니다.',
  };

  Future<void> _changePinBiometricUnlock(
    AppSettings settings,
    bool enabled,
  ) async {
    final confirmed = enabled
        ? await AppLockPrivacyService().duringConfigurationAuthentication(
            () => defaultTargetPlatform == TargetPlatform.macOS
                ? BiometricAuthService().authenticateWithBiometricsOrCompanion(
                    localizedReason:
                        'Touch ID 또는 Apple Watch를 Daily PIN 잠금에 사용합니다.',
                  )
                : BiometricAuthService().authenticate(
                    localizedReason: 'Daily PIN 잠금에 생체인식 잠금 해제를 사용합니다.',
                  ),
          )
        : await _confirmCurrentLockMethod(AppLockMethod.appPin);
    if (!confirmed) {
      return;
    }
    await _save(settings.copyWith(appLockBiometricsEnabled: enabled));
  }

  Future<bool> _confirmCurrentLockMethod(AppLockMethod method) async {
    switch (method) {
      case AppLockMethod.noPin:
        if (!mounted) {
          return false;
        }
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('잠금 방식 변경'),
                content: const Text('현재 PIN 없는 잠금 방식에서 변경을 계속할까요?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('취소'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('계속'),
                  ),
                ],
              ),
            ) ??
            false;
      case AppLockMethod.appPin:
        final repository = ref.read(settingsRepositoryProvider);
        final pinLength = await repository.appLockPinLength();
        if (!mounted) {
          return false;
        }
        return await _showPinVerificationDialog(
              context: context,
              expectedLength: pinLength,
              verifier: repository.verifyAppLockPin,
            ) ??
            false;
      case AppLockMethod.system:
        return AppLockPrivacyService().duringConfigurationAuthentication(
          () => BiometricAuthService().authenticate(
            localizedReason: 'Daily 앱 잠금을 해제하려면 인증이 필요합니다.',
            allowDeviceCredentials: true,
          ),
        );
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
      backup: false,
    );
    _queueCategoryBackup();
  }

  Future<void> _setCategoryVisible(
    AppSettings settings,
    EventCategory category,
    bool visible,
  ) async {
    final hidden = settings.hiddenCategoryIds.toSet();
    if (visible) {
      hidden.remove(category.id);
    } else {
      hidden.add(category.id);
    }
    await _save(settings.copyWith(hiddenCategoryIds: hidden.toList()));
    await ref.read(appleWidgetServiceProvider).refresh();
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
      backup: false,
    );
    await ref
        .read(eventCommandServiceProvider)
        .updateCategoryUsage(previous: category, updated: updatedCategory);
    _queueCategoryBackup();
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
      settings.copyWith(
        categories: _normalizeCategories(categories),
        hiddenCategoryIds: settings.hiddenCategoryIds
            .where((id) => id != category.id)
            .toList(),
      ),
      backup: false,
    );
    _queueCategoryBackup();
  }

  void _queueCategoryBackup() {
    unawaited(
      ref
          .read(googleDriveSyncServiceProvider)
          .syncPendingChangesNow()
          .catchError((_) {}),
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
        _googleDriveAccount = account;
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
        setState(() => _googleDriveAccount = account);
      }
      return true;
    } on Object {
      return false;
    }
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

  Future<void> _backupGoogleDriveNow() async {
    setState(() {
      _syncBusy = true;
      _syncMessage = '';
    });
    try {
      await ref
          .read(googleDriveSyncServiceProvider)
          .syncPendingChangesNow(promptIfNecessary: true);
      if (mounted) {
        final status = ref
            .read(googleDriveSyncServiceProvider)
            .statusNotifier
            .value;
        setState(
          () => _syncMessage = status.message.isEmpty
              ? '백업할 변경 사항이 없습니다.'
              : status.message,
        );
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

  Future<void> _restoreGoogleDriveNow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Google Drive에서 복원'),
        content: const Text(
          'Google Drive AppData의 일정과 설정을 이 기기에 복원할까요? '
          '이 기기의 더 최신이거나 아직 백업되지 않은 변경은 유지됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('복원'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _syncBusy = true;
      _syncMessage = '';
    });
    try {
      await ref
          .read(googleDriveSyncServiceProvider)
          .restoreNow(promptIfNecessary: true);
      if (mounted) {
        ref.read(appSettingsProvider.notifier).state = ref
            .read(settingsRepositoryProvider)
            .load();
        setState(() => _syncMessage = 'Google Drive 복원 완료');
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

  Future<void> _disconnectGoogle() async {
    final deleteBackup = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Google 연동 해지'),
        content: const Text(
          'Google 계정 연결을 해제할까요? Google Drive AppData 백업은 유지하거나 함께 삭제할 수 있습니다. 로컬 일정과 설정은 유지됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('연동만 해제'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('백업 삭제 후 해제'),
          ),
        ],
      ),
    );
    if (deleteBackup == null) {
      return;
    }

    setState(() {
      _syncBusy = true;
      _syncMessage = '';
    });
    try {
      if (deleteBackup) {
        await ref
            .read(googleDriveSyncServiceProvider)
            .deleteCloudBackup(promptIfNecessary: true);
      }
      try {
        await ref.read(googleDriveAuthServiceProvider).signOut();
      } on Object {
        // Local provider unlink must remain available even if the platform
        // cannot clear its cached Google session.
      }
      await ref.read(settingsRepositoryProvider).deleteGoogleAccount();
      if (mounted) {
        setState(() {
          _googleDriveAccount = null;
          _dailyAccount = ref.read(settingsRepositoryProvider).dailyAccount();
          _syncMessage = deleteBackup
              ? 'Google 연동과 Drive 백업을 삭제했습니다.'
              : 'Google 연동을 해지했습니다. Drive 백업은 유지됩니다.';
        });
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text(
          '이 기기의 일정, 설정, 로그인 정보를 삭제하고 시작 화면으로 돌아갑니다. '
          'Google Drive AppData의 백업은 삭제하지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _syncBusy = true;
      _syncMessage = '';
      _appleMessage = '';
    });
    try {
      final events = await ref.read(eventRepositoryProvider).allEventsForSync();
      final hasGoogleAccount = _dailyAccount?.googleAccount != null;
      final backupCompleted =
          !hasGoogleAccount ||
          await _tryFlushPendingBeforeLogout(Stopwatch()..start());
      if (!backupCompleted &&
          (!mounted || !await _confirmLogoutWithoutBackup())) {
        return;
      }

      await ref.read(googleDriveSyncServiceProvider).stop();
      await _tryCancelNotificationsBeforeReset(events);
      await ref.read(alarmServiceProvider).cancelAllEventAlarms();
      try {
        await ref.read(googleDriveAuthServiceProvider).signOut();
      } on Object {
        // Local logout must still complete if a provider token cannot be cleared.
      }
      try {
        await ref.read(appleSignInServiceProvider).signOut();
      } on Object {
        // Apple has no remote logout endpoint; local cleanup continues.
      }
      await ref.read(eventRepositoryProvider).clearAll();
      await ref.read(settingsRepositoryProvider).resetAll();
      ref.read(appSettingsProvider.notifier).state = AppSettings();
      unawaited(
        ref.read(appleWidgetServiceProvider).refresh().catchError((_) {}),
      );
      if (mounted) {
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

  Future<bool> _confirmLogoutWithoutBackup() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('백업을 완료하지 못했습니다'),
            content: const Text(
              '아직 Google Drive에 백업되지 않은 변경이 있을 수 있습니다. '
              '그래도 이 기기의 데이터를 삭제하고 로그아웃할까요?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('백업 없이 로그아웃'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteAccount() async {
    final authService = ref.read(googleDriveAuthServiceProvider);
    final dailyAccount = _dailyAccount;
    final hasGoogleAccount = dailyAccount?.googleAccount != null;
    final hasDailyAccount = dailyAccount?.hasProviders ?? false;
    final title = hasDailyAccount ? 'Daily 계정 탈퇴' : '로컬 데이터 초기화';
    final content = hasDailyAccount
        ? 'Daily 계정의 Apple/Google 연결 및 병합 정보, Google Drive AppData 백업, 이 기기의 모든 일정과 설정을 삭제하고 시작 화면으로 돌아갑니다. 향후 iCloud 저장 데이터도 이 경로에서 함께 삭제됩니다. 이 작업은 되돌릴 수 없습니다.'
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
            child: Text(hasDailyAccount ? 'Daily 계정 탈퇴' : '초기화'),
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
      await ref.read(alarmServiceProvider).cancelAllEventAlarms();
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
      ref.read(appSettingsProvider.notifier).state = AppSettings();
      unawaited(
        ref.read(appleWidgetServiceProvider).refresh().catchError((_) {}),
      );
      if (mounted) {
        setState(() {
          _appleAccount = null;
          _googleDriveAccount = null;
          _dailyAccount = null;
          _syncMessage = hasDailyAccount
              ? 'Daily 계정 탈퇴가 완료되었습니다.'
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

  Future<bool> _tryFlushPendingBeforeLogout(Stopwatch stopwatch) async {
    final syncBudget =
        _accountActionTimeout - stopwatch.elapsed - _logoutAccountReserve;
    if (syncBudget <= Duration.zero) {
      return false;
    }
    try {
      await ref
          .read(googleDriveSyncServiceProvider)
          .syncPendingChangesNow(promptIfNecessary: false)
          .timeout(syncBudget);
      return true;
    } on Object {
      return false;
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

class _AppTextSizeSlider extends StatelessWidget {
  const _AppTextSizeSlider({required this.textSize, required this.onChanged});

  final AppTextSize textSize;
  final ValueChanged<AppTextSize> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '전체 UI 글자 크기',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: _ThreeWayCapsule<AppTextSize>(
              key: const ValueKey('app-text-size-slider'),
              values: AppTextSize.values,
              selected: textSize,
              labelFor: (size) => size.label,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppLockMethodSlider extends StatelessWidget {
  const _AppLockMethodSlider({
    required this.method,
    required this.systemAuthenticationAvailable,
    required this.onChanged,
  });

  final AppLockMethod method;
  final bool systemAuthenticationAvailable;
  final ValueChanged<AppLockMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text('잠금 방식', style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: _ThreeWayCapsule<AppLockMethod>(
              key: const ValueKey('app-lock-method-slider'),
              values: AppLockMethod.values,
              selected: method,
              labelFor: (method) => switch (method) {
                AppLockMethod.noPin => 'PIN 없음',
                AppLockMethod.appPin => 'PIN 잠금',
                AppLockMethod.system => '시스템',
              },
              enabledFor: (method) =>
                  method != AppLockMethod.system ||
                  systemAuthenticationAvailable,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreeWayCapsule<T> extends StatefulWidget {
  const _ThreeWayCapsule({
    super.key,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onChanged,
    this.enabledFor,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final bool Function(T value)? enabledFor;
  final ValueChanged<T> onChanged;

  @override
  State<_ThreeWayCapsule<T>> createState() => _ThreeWayCapsuleState<T>();
}

class _ThreeWayCapsuleState<T> extends State<_ThreeWayCapsule<T>> {
  T? _dragValue;

  T get _visibleValue => _dragValue ?? widget.selected;

  @override
  Widget build(BuildContext context) {
    const height = 42.0;
    final colorScheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) =>
            _commitAt(details.localPosition.dx, constraints.maxWidth),
        onHorizontalDragStart: (details) =>
            _previewAt(details.localPosition.dx, constraints.maxWidth),
        onHorizontalDragUpdate: (details) =>
            _previewAt(details.localPosition.dx, constraints.maxWidth),
        onHorizontalDragEnd: (_) {
          final value = _dragValue;
          setState(() => _dragValue = null);
          if (value != null && _isEnabled(value)) {
            widget.onChanged(value);
          }
        },
        onHorizontalDragCancel: () => setState(() => _dragValue = null),
        child: Container(
          height: height,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: dark
                ? colorScheme.surfaceContainerHigh
                : const Color(0xffeef2f7),
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                alignment: _alignmentFor(_visibleValue),
                child: FractionallySizedBox(
                  widthFactor: 1 / widget.values.length,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(height / 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1a0f172a),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final value in widget.values)
                    Expanded(
                      child: Center(
                        child: Text(
                          widget.labelFor(value),
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: !_isEnabled(value)
                                    ? Theme.of(context).disabledColor
                                    : value == _visibleValue
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                                fontWeight: value == _visibleValue
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isEnabled(T value) => widget.enabledFor?.call(value) ?? true;

  void _previewAt(double dx, double width) {
    final value = _valueAt(dx, width);
    if (_isEnabled(value) && value != _dragValue) {
      setState(() => _dragValue = value);
    }
  }

  void _commitAt(double dx, double width) {
    final value = _valueAt(dx, width);
    if (_isEnabled(value)) {
      widget.onChanged(value);
    }
  }

  T _valueAt(double dx, double width) {
    final index = (dx / (width / widget.values.length)).floor().clamp(
      0,
      widget.values.length - 1,
    );
    return widget.values[index];
  }

  Alignment _alignmentFor(T value) {
    final index = widget.values.indexOf(value);
    if (index == 0) {
      return Alignment.centerLeft;
    }
    if (index == widget.values.length - 1) {
      return Alignment.centerRight;
    }
    return Alignment.center;
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colorScheme.outlineVariant),
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
  const _AppVersionInfo({
    required this.version,
    this.buildNumber = '',
    this.packageName = '',
  });

  final String version;
  final String buildNumber;
  final String packageName;
}

class _AppVersionTile extends StatelessWidget {
  const _AppVersionTile({required this.versionInfo, required this.onDoubleTap});

  final Future<_AppVersionInfo> versionInfo;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppVersionInfo>(
      future: versionInfo,
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info?.version ?? '확인 중';
        final buildNumber = info?.buildNumber.trim() ?? '';
        final versionLabel = buildNumber.isEmpty
            ? version
            : '$version ($buildNumber)';
        return GestureDetector(
          key: const ValueKey('daily-version-github-link'),
          behavior: HitTestBehavior.opaque,
          onDoubleTap: onDoubleTap,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('Daily 버전'),
            subtitle: Text('버전 $versionLabel · 더블 클릭하여 Github 확인하기'),
          ),
        );
      },
    );
  }
}

class _DefaultRemindersTile extends StatelessWidget {
  const _DefaultRemindersTile({
    required this.title,
    required this.values,
    required this.presets,
    required this.onChanged,
    required this.onCustom,
  });

  final String title;
  final List<int> values;
  final List<int> presets;
  final ValueChanged<List<int>> onChanged;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final selected = values.toSet();
    final options = normalizeReminderMinutes([...presets, ...values]);
    final summary = values.isEmpty
        ? '새 일정에 알림을 자동으로 추가하지 않습니다.'
        : values.map(_minutesLabel).join(', ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 4),
          Text(summary, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: const Text('없음'),
                selected: values.isEmpty,
                onSelected: (_) => onChanged(const <int>[]),
              ),
              for (final minutes in options)
                FilterChip(
                  label: Text(_minutesLabel(minutes)),
                  selected: selected.contains(minutes),
                  onSelected: (enabled) {
                    final next = values.toSet();
                    enabled ? next.add(minutes) : next.remove(minutes);
                    onChanged(normalizeReminderMinutes(next));
                  },
                ),
              IconButton.outlined(
                tooltip: '기본 알림 직접 입력',
                onPressed: onCustom,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ],
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
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 116,
            child: _ThreeWayCapsule<bool>(
              key: const ValueKey('time-format-slider'),
              values: const [false, true],
              selected: use24HourTime,
              labelFor: (value) => value ? '24h' : '12h',
              onChanged: onChanged,
            ),
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
    required this.visible,
    required this.onVisibilityChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final EventCategory category;
  final bool visible;
  final ValueChanged<bool> onVisibilityChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: '캘린더에 표시',
            child: Checkbox(
              value: visible,
              visualDensity: VisualDensity.compact,
              onChanged: (value) => onVisibilityChanged(value ?? true),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Color(category.colorValue),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
      title: Text(category.label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (category.locked)
            Tooltip(
              message: '수정 불가',
              child: Icon(
                Icons.lock_outline,
                color: Theme.of(context).disabledColor,
              ),
            )
          else ...[
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
        ],
      ),
    );
  }
}

class _GoogleDriveSyncSettings extends StatelessWidget {
  const _GoogleDriveSyncSettings({
    required this.email,
    required this.sessionConnected,
    required this.busy,
    required this.message,
    required this.onConnect,
    required this.onBackup,
    required this.onRestore,
    required this.canCancelConnection,
    required this.onCancelConnection,
    required this.onDisconnect,
    required this.hasDailyAccount,
    required this.onDeleteDailyAccount,
  });

  final String? email;
  final bool sessionConnected;
  final bool busy;
  final String message;
  final VoidCallback onConnect;
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  final bool canCancelConnection;
  final VoidCallback onCancelConnection;
  final VoidCallback onDisconnect;
  final bool hasDailyAccount;
  final VoidCallback onDeleteDailyAccount;

  @override
  Widget build(BuildContext context) {
    final linked = email != null;
    final connecting = busy && !sessionConnected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.account_circle_outlined),
          title: const Text('Google 계정'),
          subtitle: Text(linked ? email! : 'Google 로그인 시 Daily 계정에 연결됩니다.'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cloud_sync_outlined),
          title: const Text('Google Drive 동기화'),
          subtitle: Text(
            sessionConnected
                ? '이 계정의 Google Drive AppData에 일정을 백업하고 복원합니다.'
                : linked
                ? 'Google 인증 세션이 없습니다. 다시 연결하면 자동 동기화가 재개됩니다.'
                : 'Google 로그인 시 Drive AppData 권한도 함께 승인합니다.',
          ),
        ),
        Row(
          key: const ValueKey('google-drive-backup-restore-row'),
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: busy
                    ? null
                    : (sessionConnected ? onBackup : onConnect),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        sessionConnected
                            ? Icons.cloud_upload_outlined
                            : Icons.cloud_outlined,
                      ),
                label: Text(
                  connecting
                      ? 'Google 연결 중'
                      : sessionConnected
                      ? '백업'
                      : linked
                      ? 'Google 다시 연결'
                      : 'Google로 계속',
                ),
              ),
            ),
            if (sessionConnected) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onRestore,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('복원'),
                ),
              ),
            ],
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
        if (linked)
          OutlinedButton.icon(
            onPressed: busy ? null : onDisconnect,
            icon: const Icon(Icons.link_off_outlined),
            label: const Text('Google 연동 해지'),
          ),
        if (linked) const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy ? null : onDeleteDailyAccount,
          icon: const Icon(Icons.person_remove_outlined),
          label: Text(hasDailyAccount ? 'Daily 계정 탈퇴' : '로컬 데이터 초기화'),
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
    required this.onDisconnect,
  });

  final AppleAccount? account;
  final bool busy;
  final String message;
  final VoidCallback onSignIn;
  final VoidCallback onDisconnect;

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
        if (connected) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : onDisconnect,
            icon: const Icon(Icons.link_off_outlined),
            label: const Text('Apple 연동 해지'),
          ),
        ],
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

Future<String?> _showPinSetupDialog({
  required BuildContext context,
  required String title,
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) => _PinSetupDialog(title: title),
  );
}

Future<bool?> _showPinVerificationDialog({
  required BuildContext context,
  required int? expectedLength,
  required Future<bool> Function(String pin) verifier,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _PinVerificationDialog(
      expectedLength: expectedLength,
      verifier: verifier,
    ),
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
                  SizedBox.square(
                    dimension: 40,
                    child: ChoiceChip(
                      selected: _selectedColor == colorValue,
                      label: const SizedBox.shrink(),
                      labelPadding: EdgeInsets.zero,
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                      showCheckmark: false,
                      clipBehavior: Clip.antiAlias,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      avatar: CircleAvatar(
                        radius: 8,
                        backgroundColor: Color(colorValue),
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedColor = colorValue),
                    ),
                  ),
                Tooltip(
                  message: '사용자 지정 색상',
                  child: SizedBox.square(
                    dimension: 40,
                    child: ChoiceChip(
                      selected: false,
                      label: const SizedBox.shrink(),
                      labelPadding: EdgeInsets.zero,
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                      showCheckmark: false,
                      clipBehavior: Clip.antiAlias,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      avatar: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              Colors.red,
                              Colors.orange,
                              Colors.yellow,
                              Colors.green,
                              Colors.cyan,
                              Colors.blue,
                              Colors.purple,
                              Colors.red,
                            ],
                          ),
                        ),
                      ),
                      onSelected: (_) async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        await Future<void>.delayed(
                          const Duration(milliseconds: 200),
                        );
                        if (!context.mounted) {
                          return;
                        }
                        final color = await showDialog<int>(
                          context: context,
                          builder: (context) =>
                              _RgbColorDialog(initialColor: _selectedColor),
                        );
                        if (color == null || !mounted) {
                          return;
                        }
                        setState(() {
                          if (!_colorValues.contains(color)) {
                            _colorValues.add(color);
                          }
                          _selectedColor = color;
                        });
                      },
                    ),
                  ),
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

class _RgbColorDialog extends StatefulWidget {
  const _RgbColorDialog({required this.initialColor});

  final int initialColor;

  @override
  State<_RgbColorDialog> createState() => _RgbColorDialogState();
}

class _RgbColorDialogState extends State<_RgbColorDialog> {
  late final List<int> _channels;
  late final List<TextEditingController> _controllers;
  late HSVColor _hsv;

  int get _colorValue =>
      0xff000000 | (_channels[0] << 16) | (_channels[1] << 8) | _channels[2];

  @override
  void initState() {
    super.initState();
    _channels = [
      (widget.initialColor >> 16) & 0xff,
      (widget.initialColor >> 8) & 0xff,
      widget.initialColor & 0xff,
    ];
    _controllers = [
      for (final value in _channels) TextEditingController(text: '$value'),
    ];
    _hsv = HSVColor.fromColor(Color(_colorValue));
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final pickerWidth = (screenSize.width - 128).clamp(200.0, 360.0);
    final maxContentHeight = screenSize.height * 0.62;
    return AlertDialog(
      title: const Text('사용자 지정 색상'),
      content: SizedBox(
        width: pickerWidth,
        height: maxContentHeight,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _colorPalette(pickerWidth),
              const SizedBox(height: 14),
              for (var index = 0; index < 3; index++)
                _channelRow(index, const ['R', 'G', 'B'][index]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_colorValue),
          child: const Text('적용'),
        ),
      ],
    );
  }

  Widget _colorPalette(double width) {
    final size = Size(width, 180);
    return GestureDetector(
      key: const Key('category-color-palette'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _setPaletteColor(details.localPosition, size),
      onPanStart: (details) => _setPaletteColor(details.localPosition, size),
      onPanUpdate: (details) => _setPaletteColor(details.localPosition, size),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red,
                        Colors.yellow,
                        Colors.green,
                        Colors.cyan,
                        Colors.blue,
                        Colors.purple,
                        Colors.red,
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.transparent, Colors.black],
                      stops: [0, 0.5, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: (_hsv.hue / 360 * size.width - 8).clamp(
                  0,
                  size.width - 16,
                ),
                top: (_paletteVerticalPosition * size.height - 8).clamp(
                  0,
                  size.height - 16,
                ),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color(_colorValue),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get _paletteVerticalPosition {
    if (_hsv.value >= 0.999 && _hsv.saturation < 0.999) {
      return _hsv.saturation / 2;
    }
    return 0.5 + (1 - _hsv.value) / 2;
  }

  void _setPaletteColor(Offset position, Size size) {
    final hue = (position.dx / size.width).clamp(0.0, 1.0) * 360;
    final vertical = (position.dy / size.height).clamp(0.0, 1.0);
    final saturation = vertical <= 0.5 ? vertical * 2 : 1.0;
    final value = vertical <= 0.5 ? 1.0 : (1 - vertical) * 2;
    _applyHsv(HSVColor.fromAHSV(1, hue, saturation, value));
  }

  void _applyHsv(HSVColor value) {
    final color = value.toColor();
    setState(() {
      _hsv = value;
      _channels[0] = (color.r * 255).round();
      _channels[1] = (color.g * 255).round();
      _channels[2] = (color.b * 255).round();
      for (var index = 0; index < 3; index++) {
        _controllers[index].text = '${_channels[index]}';
      }
    });
  }

  void _syncHsvFromChannels() {
    _hsv = HSVColor.fromColor(Color(_colorValue));
  }

  Widget _channelRow(int index, String label) {
    return Row(
      children: [
        SizedBox(width: 22, child: Text(label)),
        Expanded(
          child: Slider(
            value: _channels[index].toDouble(),
            min: 0,
            max: 255,
            divisions: 255,
            label: '${_channels[index]}',
            onChanged: (value) {
              final channel = value.round();
              setState(() {
                _channels[index] = channel;
                _controllers[index].text = '$channel';
                _syncHsvFromChannels();
              });
            },
          ),
        ),
        SizedBox(
          width: 58,
          child: TextField(
            controller: _controllers[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 3,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(counterText: '', isDense: true),
            onChanged: (value) {
              final channel = int.tryParse(value);
              if (channel == null) {
                return;
              }
              setState(() {
                _channels[index] = channel.clamp(0, 255).toInt();
                _syncHsvFromChannels();
              });
            },
            onSubmitted: (_) {
              _controllers[index].text = '${_channels[index]}';
            },
          ),
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

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog({required this.title});

  final String title;

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  var _pin = '';
  String? _firstPin;
  var _error = '';

  bool get _confirming => _firstPin != null;

  void _appendDigit(String digit) {
    setState(() {
      _pin += digit;
      _error = '';
    });
  }

  void _removeDigit() {
    if (_pin.isEmpty) {
      return;
    }
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = '';
    });
  }

  void _continue() {
    if (!_confirming) {
      if (_pin.length < 4) {
        setState(() => _error = 'PIN은 4자리 이상이어야 합니다.');
        return;
      }
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _error = '';
      });
      return;
    }
    if (_pin != _firstPin) {
      setState(() {
        _pin = '';
        _error = 'PIN이 일치하지 않습니다. 다시 입력하세요.';
      });
      return;
    }
    Navigator.of(context).pop(_pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _confirming ? 'PIN을 한 번 더 입력하세요.' : '4자리 이상의 PIN을 입력하세요.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            _PinEntryDots(filledCount: _pin.length, showOnlyFilled: true),
            SizedBox(
              height: 22,
              child: Text(
                _error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            _SecurePinKeypad(onDigit: _appendDigit, onBackspace: _removeDigit),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _continue,
          child: Text(_confirming ? '설정' : '다음'),
        ),
      ],
    );
  }
}

class _PinVerificationDialog extends StatefulWidget {
  const _PinVerificationDialog({
    required this.expectedLength,
    required this.verifier,
  });

  final int? expectedLength;
  final Future<bool> Function(String pin) verifier;

  @override
  State<_PinVerificationDialog> createState() => _PinVerificationDialogState();
}

class _PinVerificationDialogState extends State<_PinVerificationDialog> {
  static const _legacyCheckDelay = Duration(milliseconds: 700);

  Timer? _legacyTimer;
  var _pin = '';
  var _checking = false;
  var _error = '';

  @override
  void dispose() {
    _legacyTimer?.cancel();
    super.dispose();
  }

  void _appendDigit(String digit) {
    _legacyTimer?.cancel();
    if (_checking ||
        (widget.expectedLength != null &&
            _pin.length >= widget.expectedLength!)) {
      return;
    }
    setState(() {
      _pin += digit;
      _error = '';
    });
    if (widget.expectedLength != null && _pin.length == widget.expectedLength) {
      unawaited(_verify());
    } else if (widget.expectedLength == null && _pin.length >= 4) {
      _legacyTimer = Timer(_legacyCheckDelay, () => unawaited(_verify()));
    }
  }

  void _removeDigit() {
    _legacyTimer?.cancel();
    if (_checking || _pin.isEmpty) {
      return;
    }
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = '';
    });
  }

  Future<void> _verify() async {
    if (_checking || _pin.isEmpty) {
      return;
    }
    final pin = _pin;
    setState(() => _checking = true);
    final verified = await widget.verifier(pin);
    if (!mounted) {
      return;
    }
    if (verified) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _checking = false;
      _pin = '';
      _error = 'PIN이 일치하지 않습니다.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('PIN 확인'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('앱 잠금을 해제하려면 PIN을 입력하세요.'),
            const SizedBox(height: 18),
            _PinEntryDots(
              filledCount: _pin.length,
              expectedCount: widget.expectedLength,
            ),
            SizedBox(
              height: 22,
              child: Text(
                _error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            _SecurePinKeypad(
              enabled: !_checking,
              onDigit: _appendDigit,
              onBackspace: _removeDigit,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
      ],
    );
  }
}

class _PinEntryDots extends StatelessWidget {
  const _PinEntryDots({
    required this.filledCount,
    this.expectedCount,
    this.showOnlyFilled = false,
  });

  final int filledCount;
  final int? expectedCount;
  final bool showOnlyFilled;

  @override
  Widget build(BuildContext context) {
    final count = showOnlyFilled
        ? filledCount
        : expectedCount ?? (filledCount > 6 ? filledCount : 6);
    return Wrap(
      key: const ValueKey('pin-entry-dots'),
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: List.generate(count, (index) {
        final filled = index < filledCount;
        return Container(
          key: ValueKey('pin-entry-dot-$index'),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: filled
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _SecurePinKeypad extends StatelessWidget {
  const _SecurePinKeypad({
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: [
        for (final digit in digits)
          digit.isEmpty
              ? const SizedBox.shrink()
              : TextButton(
                  onPressed: enabled ? () => onDigit(digit) : null,
                  child: Text(
                    digit,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
        IconButton(
          tooltip: '한 자리 지우기',
          onPressed: enabled ? onBackspace : null,
          icon: const Icon(Icons.backspace_outlined),
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
