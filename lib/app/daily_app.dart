import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/app_providers.dart';
import '../core/auth/google_account.dart';
import '../core/security/biometric_auth_service.dart';
import '../core/security/app_lock_privacy_service.dart';
import '../core/settings/app_settings.dart';
import '../features/calendar/presentation/month_calendar_page.dart';
import '../features/onboarding/presentation/welcome_page.dart';
import 'daily_theme.dart';

class DailyApp extends ConsumerWidget {
  const DailyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    unawaited(
      AppLockPrivacyService().setEnabled(
        settings.appLockEnabled,
        method: settings.appLockMethod,
      ),
    );

    return MaterialApp(
      key: ValueKey(
        settings.onboardingCompleted ? 'daily-home' : 'daily-onboarding',
      ),
      title: 'Daily',
      debugShowCheckedModeBanner: false,
      theme: DailyTheme.light(),
      darkTheme: DailyTheme.dark(),
      themeMode: switch (settings.themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      builder: (context, child) {
        var content = child ?? const SizedBox.shrink();
        if (settings.onboardingCompleted) {
          content = _AppLockGate(
            enabled: settings.appLockEnabled,
            child: content,
          );
        }
        final brightness = Theme.of(context).brightness;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                appTextScaleForPlatform(
                  settings.appTextSize,
                  defaultTargetPlatform,
                ),
              ),
            ),
            child: content,
          ),
        );
      },
      home: settings.onboardingCompleted
          ? const _AppHome()
          : const WelcomePage(),
    );
  }
}

double appTextScaleForPlatform(AppTextSize size, TargetPlatform platform) {
  if (platform == TargetPlatform.macOS) {
    return switch (size) {
      AppTextSize.basic => 1.0,
      AppTextSize.large => 1.15,
      AppTextSize.extraLarge => 1.3,
    };
  }
  return size.scale;
}

bool shouldAutomaticallyRequestBiometrics(TargetPlatform platform) {
  return true;
}

class _AppLockGate extends ConsumerStatefulWidget {
  const _AppLockGate({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  ConsumerState<_AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<_AppLockGate>
    with WidgetsBindingObserver {
  static const _legacyPinCheckDelay = Duration(milliseconds: 700);

  final _biometricAuth = BiometricAuthService();
  final _pinKeyboardFocusNode = FocusNode();
  Timer? _legacyPinTimer;
  String _pin = '';
  int? _pinLength;
  late var _unlocked = !widget.enabled;
  var _checking = false;
  var _error = '';
  var _pinEntryVisible = false;
  var _pinBiometricAttemptedForCurrentLock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.enabled) {
      unawaited(_prepareLockScreen());
    }
  }

  @override
  void didUpdateWidget(covariant _AppLockGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _legacyPinTimer?.cancel();
      _unlocked = true;
      _pin = '';
      _error = '';
      return;
    }
    if (!oldWidget.enabled) {
      // Enabling the lock in Settings should not immediately lock the user out.
      _unlocked = true;
      if (ref.read(appSettingsProvider).appLockMethod == AppLockMethod.appPin) {
        unawaited(_loadPinLength());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _legacyPinTimer?.cancel();
    _pinKeyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_checking ||
        AppLockPrivacyService.configurationAuthenticationInProgress) {
      return;
    }
    final settings = ref.read(appSettingsProvider);
    if (widget.enabled &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive ||
            state == AppLifecycleState.hidden)) {
      _lock();
    } else if (widget.enabled && state == AppLifecycleState.resumed) {
      if (_unlocked) {
        return;
      }
      if (settings.appLockMethod == AppLockMethod.noPin) {
        setState(() => _unlocked = true);
      } else if (settings.appLockMethod == AppLockMethod.appPin &&
          settings.appLockBiometricsEnabled &&
          !_pinBiometricAttemptedForCurrentLock) {
        unawaited(_tryPinBiometricAuthentication());
      } else if (settings.appLockMethod == AppLockMethod.system &&
          shouldAutomaticallyRequestBiometrics(defaultTargetPlatform)) {
        unawaited(_trySystemAuthentication());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _unlocked) {
      return widget.child;
    }
    final lockMethod = ref.watch(appSettingsProvider).appLockMethod;

    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: true, child: widget.child),
        Scaffold(
          key: const ValueKey('app-lock-screen'),
          body: KeyboardListener(
            focusNode: _pinKeyboardFocusNode,
            autofocus: lockMethod == AppLockMethod.appPin && _pinEntryVisible,
            onKeyEvent: _handlePinKeyEvent,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.lock_outline, size: 42),
                        const SizedBox(height: 18),
                        Text(
                          switch (lockMethod) {
                            AppLockMethod.noPin => '잠금 상태에서는 화면을 볼 수 없습니다.',
                            AppLockMethod.appPin when !_pinEntryVisible =>
                              '잠금 상태입니다.',
                            AppLockMethod.appPin => 'PIN 입력',
                            AppLockMethod.system => '잠금 상태입니다.',
                          },
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 26),
                        if (lockMethod == AppLockMethod.appPin) ...[
                          if (!_pinEntryVisible) ...[
                            FilledButton.icon(
                              key: const ValueKey('show-pin-entry-button'),
                              onPressed: _checking ? null : _showPinEntry,
                              icon: const Icon(Icons.password_outlined),
                              label: const Text('비밀번호를 통해 잠금해제'),
                            ),
                            if (_error.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ] else ...[
                            _PinDots(filledCount: _pin.length),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 24,
                              child: Text(
                                _error,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _PinKeypad(
                              enabled: !_checking,
                              onDigit: _appendDigit,
                              onBackspace: _removeDigit,
                            ),
                          ],
                        ] else if (lockMethod == AppLockMethod.system) ...[
                          Text(
                            '기기의 Face ID, Touch ID 또는 시스템 비밀번호로 확인합니다.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _checking
                                ? null
                                : _trySystemAuthentication,
                            icon: const Icon(Icons.lock_open_outlined),
                            label: const Text('시스템 잠금으로 해제'),
                          ),
                          if (_error.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ] else ...[
                          const SizedBox.shrink(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _prepareLockScreen() async {
    final settings = ref.read(appSettingsProvider);
    if (settings.appLockMethod == AppLockMethod.noPin) {
      if (mounted) {
        setState(() => _unlocked = true);
      }
      return;
    }
    if (settings.appLockMethod == AppLockMethod.appPin) {
      await _loadPinLength();
      if (settings.appLockBiometricsEnabled) {
        await _tryPinBiometricAuthentication();
      }
    }
    if (!mounted) {
      return;
    }
    if (settings.appLockMethod == AppLockMethod.system &&
        shouldAutomaticallyRequestBiometrics(defaultTargetPlatform)) {
      await _trySystemAuthentication();
    }
  }

  Future<void> _loadPinLength() async {
    final pinLength = await ref
        .read(settingsRepositoryProvider)
        .appLockPinLength();
    if (!mounted) {
      return;
    }
    setState(() => _pinLength = pinLength);
  }

  void _lock() {
    _legacyPinTimer?.cancel();
    if (mounted) {
      setState(() {
        _pin = '';
        _error = '';
        _checking = false;
        _pinEntryVisible = false;
        _pinBiometricAttemptedForCurrentLock = false;
        _unlocked = false;
      });
    }
  }

  void _appendDigit(String digit) {
    _legacyPinTimer?.cancel();
    final expectedLength = _pinLength;
    if (_checking ||
        (expectedLength != null && _pin.length >= expectedLength)) {
      return;
    }
    setState(() {
      _pin += digit;
      _error = '';
    });

    if (expectedLength != null && _pin.length == expectedLength) {
      unawaited(_verifyPin());
      return;
    }
    if (expectedLength == null && _pin.length >= 4) {
      _legacyPinTimer = Timer(_legacyPinCheckDelay, () {
        unawaited(_verifyPin(keepInputOnFailure: true));
      });
    }
  }

  void _showPinEntry() {
    setState(() {
      _pinEntryVisible = true;
      _error = '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pinKeyboardFocusNode.requestFocus();
      }
    });
  }

  void _handlePinKeyEvent(KeyEvent event) {
    if (defaultTargetPlatform != TargetPlatform.macOS ||
        !_pinEntryVisible ||
        event is! KeyDownEvent) {
      return;
    }
    final digit = event.character ?? event.logicalKey.keyLabel;
    if (RegExp(r'^\d$').hasMatch(digit)) {
      _appendDigit(digit);
    } else if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      _removeDigit();
    }
  }

  void _removeDigit() {
    _legacyPinTimer?.cancel();
    if (_checking || _pin.isEmpty) {
      return;
    }
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = '';
    });
  }

  Future<void> _verifyPin({bool keepInputOnFailure = false}) async {
    if (_checking || _pin.isEmpty) {
      return;
    }
    final submittedPin = _pin;
    setState(() => _checking = true);
    final repository = ref.read(settingsRepositoryProvider);
    final ok = await repository.verifyAppLockPin(submittedPin);
    if (!mounted) {
      return;
    }
    if (ok) {
      if (_pinLength == null) {
        await repository.saveAppLockPin(submittedPin);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _unlocked = true;
        _error = '';
        _checking = false;
      });
    } else {
      setState(() {
        _checking = false;
        _error = keepInputOnFailure
            ? 'PIN을 계속 입력하거나 지워서 다시 입력하세요.'
            : 'PIN이 일치하지 않습니다.';
        if (!keepInputOnFailure) {
          _pin = '';
        }
      });
    }
  }

  Future<void> _trySystemAuthentication() async {
    if (_checking) {
      return;
    }
    setState(() {
      _checking = true;
      _error = '';
    });
    final authenticated = await _biometricAuth.authenticate(
      localizedReason: 'Daily 잠금을 해제하려면 인증이 필요합니다.',
      allowDeviceCredentials: true,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _checking = false;
      if (authenticated) {
        _unlocked = true;
      } else {
        _error = '시스템 인증을 완료하지 못했습니다.';
      }
    });
  }

  Future<void> _tryPinBiometricAuthentication() async {
    if (_checking || _unlocked || _pinBiometricAttemptedForCurrentLock) {
      return;
    }
    setState(() {
      _checking = true;
      _error = '';
      _pinBiometricAttemptedForCurrentLock = true;
    });
    final authenticated = defaultTargetPlatform == TargetPlatform.macOS
        ? await _biometricAuth.authenticateWithBiometricsOrCompanion(
            localizedReason: 'Touch ID 또는 Apple Watch로 Daily PIN 잠금을 해제합니다.',
          )
        : await _biometricAuth.authenticate(
            localizedReason: 'Daily PIN 잠금을 생체인식으로 해제합니다.',
          );
    if (!mounted) {
      return;
    }
    setState(() {
      _checking = false;
      if (authenticated) {
        _unlocked = true;
      } else {
        _error = '생체인식을 완료하지 못했습니다. PIN을 입력해 주세요.';
        _pinEntryVisible = true;
      }
    });
    if (!authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pinKeyboardFocusNode.requestFocus();
        }
      });
    }
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.filledCount});

  final int filledCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 13,
      child: Wrap(
        key: const ValueKey('pin-entry-dots'),
        alignment: WrapAlignment.center,
        spacing: 14,
        children: List.generate(
          filledCount,
          (index) => Container(
            key: ValueKey('pin-unlock-dot-$index'),
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,
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
        Semantics(
          label: '한 자리 지우기',
          button: true,
          child: IconButton(
            onPressed: enabled ? onBackspace : null,
            icon: const Icon(Icons.backspace_outlined),
          ),
        ),
      ],
    );
  }
}

class _AppHome extends ConsumerStatefulWidget {
  const _AppHome();

  @override
  ConsumerState<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends ConsumerState<_AppHome>
    with WidgetsBindingObserver {
  static const _syncRestoreRetryDelays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 3),
    Duration(seconds: 8),
  ];

  var _servicesStarted = false;
  Future<bool>? _syncStartOperation;
  Timer? _syncRestoreRetryTimer;
  var _syncRestoreRetryIndex = 0;
  ValueNotifier<int>? _settingsRevisionNotifier;
  VoidCallback? _settingsRevisionListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLocalNotificationServices();
    _startSyncIfConnected();
    _refreshAppleWidgets();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncRestoreRetryTimer?.cancel();
    final listener = _settingsRevisionListener;
    final notifier = _settingsRevisionNotifier;
    if (listener != null) {
      notifier?.removeListener(listener);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _syncRestoreRetryTimer?.cancel();
        _syncRestoreRetryIndex = 0;
        _startSyncIfConnected();
        _refreshAppleWidgets();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _syncBeforeBackgroundOrExit();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppSettings>(appSettingsProvider, (previous, next) {
      if (previous != next) {
        _refreshAppleWidgets();
      }
    });
    return const MonthCalendarPage();
  }

  void _refreshAppleWidgets() {
    unawaited(
      ref.read(appleWidgetServiceProvider).refresh().catchError((_) {}),
    );
  }

  Future<void> _startSyncIfConnected() async {
    final activeOperation = _syncStartOperation;
    if (activeOperation != null) {
      await activeOperation;
      return;
    }
    final operation = _tryStartSyncIfConnected();
    _syncStartOperation = operation;
    try {
      final started = await operation;
      if (started) {
        _syncRestoreRetryTimer?.cancel();
        _syncRestoreRetryIndex = 0;
      } else {
        _scheduleSyncRestoreRetry();
      }
    } finally {
      if (identical(_syncStartOperation, operation)) {
        _syncStartOperation = null;
      }
    }
  }

  Future<bool> _tryStartSyncIfConnected() async {
    final settingsRepository = ref.read(settingsRepositoryProvider);
    try {
      final auth = ref.read(googleDriveAuthServiceProvider);
      final account = await auth.restorePreviousSignIn();
      var dailyAccount = settingsRepository.dailyAccount();
      if (account != null && !settingsRepository.hasStoredDailyAccount) {
        // Migrate the pre-Daily-account Google session once. New Apple-only
        // accounts always persist first, so they never attach Google silently.
        await settingsRepository.saveGoogleAccount(
          GoogleAccount(email: account.email, displayName: account.displayName),
        );
        dailyAccount = settingsRepository.dailyAccount();
      }

      final linkedGoogleEmail = dailyAccount?.googleAccount?.email;
      if (linkedGoogleEmail == null) {
        return false;
      }
      if (account != null &&
          linkedGoogleEmail.toLowerCase() != account.email.toLowerCase()) {
        return false;
      }

      // This call is always non-interactive. It also restores desktop OAuth
      // tokens when account metadata was temporarily unavailable.
      final headers = await auth.authorizationHeaders();
      if (headers == null) {
        return false;
      }
      _startPostLoginServices();
      return true;
    } on Object {
      // Google Drive sync is optional; local calendar use stays available.
      return false;
    }
  }

  void _scheduleSyncRestoreRetry() {
    if (!mounted || _servicesStarted || _syncRestoreRetryTimer != null) {
      return;
    }
    final linkedGoogleAccount = ref
        .read(settingsRepositoryProvider)
        .dailyAccount()
        ?.googleAccount;
    if (linkedGoogleAccount == null ||
        _syncRestoreRetryIndex >= _syncRestoreRetryDelays.length) {
      return;
    }
    final delay = _syncRestoreRetryDelays[_syncRestoreRetryIndex++];
    _syncRestoreRetryTimer = Timer(delay, () {
      _syncRestoreRetryTimer = null;
      if (mounted) {
        _startSyncIfConnected();
      }
    });
  }

  void _startPostLoginServices() {
    _listenForSyncedSettings();
    if (_servicesStarted) {
      unawaited(
        Future.microtask(() async {
          await _syncGoogleDriveSnapshot();
        }).catchError((_) {}),
      );
      return;
    }
    _servicesStarted = true;
    unawaited(
      Future.microtask(() async {
        await ref.read(syncServiceProvider).start();
        _refreshSettingsState();
      }).catchError((_) {}),
    );
  }

  void _listenForSyncedSettings() {
    if (_settingsRevisionListener != null) {
      return;
    }
    void listener() => _refreshSettingsState();
    final notifier = ref
        .read(googleDriveSyncServiceProvider)
        .settingsRevisionNotifier;
    _settingsRevisionNotifier = notifier;
    _settingsRevisionListener = listener;
    notifier.addListener(listener);
  }

  void _syncBeforeBackgroundOrExit() {
    unawaited(
      Future.microtask(() async {
        await ref.read(googleDriveSyncServiceProvider).syncPendingChangesNow();
      }).catchError((_) {}),
    );
  }

  Future<void> _syncGoogleDriveSnapshot() async {
    await ref.read(googleDriveSyncServiceProvider).syncOnResume();
    _refreshSettingsState();
  }

  void _refreshSettingsState() {
    if (!mounted) {
      return;
    }
    ref.read(appSettingsProvider.notifier).state = ref
        .read(settingsRepositoryProvider)
        .load();
  }

  void _startLocalNotificationServices() {
    unawaited(
      Future.microtask(() async {
        final notificationService = ref.read(notificationServiceProvider);
        await notificationService.initialize();
        final alarmService = ref.read(alarmServiceProvider);
        await alarmService.requestAuthorization();

        final settings = ref.read(appSettingsProvider);
        if (settings.morningBriefingEnabled) {
          await notificationService.scheduleMorningBriefing(
            hour: settings.morningBriefingHour,
            minute: settings.morningBriefingMinute,
          );
        }

        final events = await ref
            .read(eventRepositoryProvider)
            .allEventsForSync();
        for (final event in events) {
          if (!event.isDeleted) {
            await notificationService.scheduleEventReminder(event);
            await alarmService.scheduleEventAlarm(event);
          }
        }
      }).catchError((_) {}),
    );
  }
}
