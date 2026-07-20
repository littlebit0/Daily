import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../auth/apple_account.dart';
import '../auth/daily_account.dart';
import '../auth/google_account.dart';
import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_category.dart';
import 'app_settings.dart';

class SettingsRepository {
  SettingsRepository({
    required SharedPreferences preferences,
    FlutterSecureStorage? secureStorage,
  }) : _preferences = preferences,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final SharedPreferences _preferences;
  final FlutterSecureStorage _secureStorage;

  static const _defaultReminderKey = 'defaultReminderMinutes';
  static const _defaultReminderListKey = 'defaultReminderMinutesList';
  static const _allDayReminderHourKey = 'allDayReminderHour';
  static const _allDayReminderMinuteKey = 'allDayReminderMinute';
  static const _briefingHourKey = 'morningBriefingHour';
  static const _briefingMinuteKey = 'morningBriefingMinute';
  static const _briefingEnabledKey = 'morningBriefingEnabled';
  static const _weekStartsOnMondayKey = 'weekStartsOnMonday';
  static const _showLunarDatesKey = 'showLunarDates';
  static const _onboardingCompletedKey = 'onboardingCompleted';
  static const _aiEnabledKey = 'aiEnabled';
  static const _aiComplexOnlyKey = 'aiOnlyForComplexInput';
  static const _blockSensitiveAiKey = 'blockSensitiveAi';
  static const _categoriesKey = 'eventCategories';
  static const _dDayReminderOffsetsKey = 'dDayReminderOffsets';
  static const _appTextSizeKey = 'appTextSize';
  static const _legacyCalendarEventTextSizeKey = 'calendarEventTextSize';
  static const _legacyCalendarDensityKey = 'calendarDensity';
  static const _defaultCalendarViewKey = 'defaultCalendarView';
  static const _hiddenCategoryIdsKey = 'hiddenCategoryIds';
  static const _calendarShowHolidaysKey = 'calendarShowHolidays';
  static const _calendarDdayOnlyKey = 'calendarDdayOnly';
  static const _hideSensitiveEventsKey = 'hideSensitiveEvents';
  static const _hideSensitiveNotificationsKey = 'hideSensitiveNotifications';
  static const _appLockEnabledKey = 'appLockEnabled';
  static const _appLockBiometricsEnabledKey = 'appLockBiometricsEnabled';
  static const _use24HourTimeKey = 'use24HourTime';
  static const _deviceIdKey = 'deviceId';
  static const _appleUserIdentifierKey = 'appleUserIdentifier';
  static const _appleEmailKey = 'appleEmail';
  static const _appleGivenNameKey = 'appleGivenName';
  static const _appleFamilyNameKey = 'appleFamilyName';
  static const _dailyAccountKey = 'dailyAccount';
  static const _geminiKey = 'geminiApiKey';
  static const _appLockPinHashKey = 'appLockPinHash';
  static const _appLockPinLengthKey = 'appLockPinLength';

  AppSettings load() {
    return AppSettings(
      defaultReminderMinutesList: _loadDefaultReminderMinutes(),
      allDayReminderHour: _preferences.getInt(_allDayReminderHourKey) ?? 9,
      allDayReminderMinute: _preferences.getInt(_allDayReminderMinuteKey) ?? 0,
      morningBriefingHour: _preferences.getInt(_briefingHourKey) ?? 8,
      morningBriefingMinute: _preferences.getInt(_briefingMinuteKey) ?? 0,
      morningBriefingEnabled: _preferences.getBool(_briefingEnabledKey) ?? true,
      weekStartsOnMonday: _preferences.getBool(_weekStartsOnMondayKey) ?? false,
      showLunarDates: _preferences.getBool(_showLunarDatesKey) ?? true,
      onboardingCompleted:
          _preferences.getBool(_onboardingCompletedKey) ?? false,
      aiEnabled: _preferences.getBool(_aiEnabledKey) ?? false,
      aiOnlyForComplexInput: _preferences.getBool(_aiComplexOnlyKey) ?? true,
      blockSensitiveAi: _preferences.getBool(_blockSensitiveAiKey) ?? true,
      categories: _loadCategories(),
      dDayReminderOffsets: _loadDdayOffsets(),
      appTextSize: AppTextSize.fromName(
        _preferences.getString(_appTextSizeKey) ??
            _preferences.getString(_legacyCalendarEventTextSizeKey),
      ),
      defaultCalendarView: CalendarViewMode.fromName(
        _preferences.getString(_defaultCalendarViewKey),
      ),
      hiddenCategoryIds: _loadStringList(_hiddenCategoryIdsKey),
      calendarShowHolidays:
          _preferences.getBool(_calendarShowHolidaysKey) ?? true,
      calendarDdayOnly: _preferences.getBool(_calendarDdayOnlyKey) ?? false,
      hideSensitiveEvents:
          _preferences.getBool(_hideSensitiveEventsKey) ?? false,
      hideSensitiveNotifications:
          _preferences.getBool(_hideSensitiveNotificationsKey) ?? false,
      appLockEnabled: _preferences.getBool(_appLockEnabledKey) ?? false,
      appLockBiometricsEnabled:
          _preferences.getBool(_appLockBiometricsEnabledKey) ?? false,
      use24HourTime: _preferences.getBool(_use24HourTimeKey) ?? true,
    );
  }

  Future<void> save(AppSettings settings) async {
    await _preferences.setString(
      _defaultReminderListKey,
      jsonEncode(settings.defaultReminderMinutesList),
    );
    if (settings.defaultReminderMinutesList.isEmpty) {
      await _preferences.remove(_defaultReminderKey);
    } else {
      await _preferences.setInt(
        _defaultReminderKey,
        settings.defaultReminderMinutesList.first,
      );
    }
    await _preferences.setInt(
      _allDayReminderHourKey,
      settings.allDayReminderHour,
    );
    await _preferences.setInt(
      _allDayReminderMinuteKey,
      settings.allDayReminderMinute,
    );
    await _preferences.setInt(_briefingHourKey, settings.morningBriefingHour);
    await _preferences.setInt(
      _briefingMinuteKey,
      settings.morningBriefingMinute,
    );
    await _preferences.setBool(
      _briefingEnabledKey,
      settings.morningBriefingEnabled,
    );
    await _preferences.setBool(
      _weekStartsOnMondayKey,
      settings.weekStartsOnMonday,
    );
    await _preferences.setBool(_showLunarDatesKey, settings.showLunarDates);
    await _preferences.setBool(
      _onboardingCompletedKey,
      settings.onboardingCompleted,
    );
    await _preferences.setBool(_aiEnabledKey, settings.aiEnabled);
    await _preferences.setBool(
      _aiComplexOnlyKey,
      settings.aiOnlyForComplexInput,
    );
    await _preferences.setBool(_blockSensitiveAiKey, settings.blockSensitiveAi);
    await _preferences.setString(
      _categoriesKey,
      jsonEncode(
        settings.categories.map((category) => category.toJson()).toList(),
      ),
    );
    await _preferences.setString(
      _dDayReminderOffsetsKey,
      jsonEncode(settings.dDayReminderOffsets),
    );
    await _preferences.setString(_appTextSizeKey, settings.appTextSize.name);
    await _preferences.remove(_legacyCalendarEventTextSizeKey);
    await _preferences.remove(_legacyCalendarDensityKey);
    await _preferences.setString(
      _defaultCalendarViewKey,
      settings.defaultCalendarView.name,
    );
    await _preferences.setString(
      _hiddenCategoryIdsKey,
      jsonEncode(settings.hiddenCategoryIds),
    );
    await _preferences.setBool(
      _calendarShowHolidaysKey,
      settings.calendarShowHolidays,
    );
    await _preferences.setBool(_calendarDdayOnlyKey, settings.calendarDdayOnly);
    await _preferences.setBool(
      _hideSensitiveEventsKey,
      settings.hideSensitiveEvents,
    );
    await _preferences.setBool(
      _hideSensitiveNotificationsKey,
      settings.hideSensitiveNotifications,
    );
    await _preferences.setBool(_appLockEnabledKey, settings.appLockEnabled);
    await _preferences.setBool(
      _appLockBiometricsEnabledKey,
      settings.appLockBiometricsEnabled,
    );
    await _preferences.setBool(_use24HourTimeKey, settings.use24HourTime);
  }

  List<int> _loadDefaultReminderMinutes() {
    final raw = _preferences.getString(_defaultReminderListKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return normalizeReminderMinutes(decoded.whereType<int>());
        }
      } on FormatException {
        // Fall through to the legacy single-value setting.
      }
    }
    return normalizeReminderMinutes([
      _preferences.getInt(_defaultReminderKey) ?? 60,
    ]);
  }

  Future<void> completeOnboarding() async {
    await _preferences.setBool(_onboardingCompletedKey, true);
  }

  Future<String> deviceId() async {
    final existing = _preferences.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final created = const Uuid().v4();
    await _preferences.setString(_deviceIdKey, created);
    return created;
  }

  AppleAccount? appleAccount() {
    final userIdentifier = _preferences.getString(_appleUserIdentifierKey);
    if (userIdentifier == null || userIdentifier.trim().isEmpty) {
      return null;
    }
    return AppleAccount(
      userIdentifier: userIdentifier,
      email: _stringOrNull(_preferences.getString(_appleEmailKey)),
      givenName: _stringOrNull(_preferences.getString(_appleGivenNameKey)),
      familyName: _stringOrNull(_preferences.getString(_appleFamilyNameKey)),
    );
  }

  DailyAccount? dailyAccount() {
    final stored = _storedDailyAccount();
    if (stored != null) {
      return stored;
    }
    final apple = appleAccount();
    if (apple == null) {
      return null;
    }
    return DailyAccount(id: const Uuid().v4(), appleAccount: apple);
  }

  bool get hasStoredDailyAccount => _storedDailyAccount() != null;

  Future<void> saveAppleAccount(AppleAccount account) async {
    final dailyAccount = _currentOrNewDailyAccount().copyWith(
      appleAccount: account,
    );
    await _saveDailyAccount(dailyAccount);
    await _preferences.setString(
      _appleUserIdentifierKey,
      account.userIdentifier,
    );
    await _setNullableString(_appleEmailKey, account.email);
    await _setNullableString(_appleGivenNameKey, account.givenName);
    await _setNullableString(_appleFamilyNameKey, account.familyName);
  }

  Future<void> deleteAppleAccount() async {
    await _preferences.remove(_appleUserIdentifierKey);
    await _preferences.remove(_appleEmailKey);
    await _preferences.remove(_appleGivenNameKey);
    await _preferences.remove(_appleFamilyNameKey);
    final dailyAccount = _storedDailyAccount();
    if (dailyAccount != null) {
      await _saveDailyAccount(dailyAccount.copyWith(clearAppleAccount: true));
    }
  }

  Future<void> saveGoogleAccount(GoogleAccount account) async {
    await _saveDailyAccount(
      _currentOrNewDailyAccount().copyWith(googleAccount: account),
    );
  }

  Future<void> deleteGoogleAccount() async {
    final dailyAccount = _storedDailyAccount();
    if (dailyAccount != null) {
      await _saveDailyAccount(dailyAccount.copyWith(clearGoogleAccount: true));
    }
  }

  Future<void> deleteDailyAccount() async {
    await _preferences.remove(_dailyAccountKey);
    await _preferences.remove(_appleUserIdentifierKey);
    await _preferences.remove(_appleEmailKey);
    await _preferences.remove(_appleGivenNameKey);
    await _preferences.remove(_appleFamilyNameKey);
  }

  Future<String?> geminiApiKey() {
    return _secureStorage.read(key: _geminiKey);
  }

  Future<void> saveGeminiApiKey(String value) {
    return _secureStorage.write(key: _geminiKey, value: value.trim());
  }

  Future<void> deleteGeminiApiKey() {
    return _deleteSecureStorageKey(_geminiKey);
  }

  Future<void> saveAppLockPin(String pin) async {
    await _secureStorage.write(key: _appLockPinHashKey, value: _hashPin(pin));
    await _secureStorage.write(
      key: _appLockPinLengthKey,
      value: '${pin.length}',
    );
  }

  Future<void> deleteAppLockPin() async {
    await _deleteSecureStorageKey(_appLockPinHashKey);
    await _deleteSecureStorageKey(_appLockPinLengthKey);
  }

  Future<int?> appLockPinLength() async {
    final raw = await _secureStorage.read(key: _appLockPinLengthKey);
    final length = int.tryParse(raw ?? '');
    return length != null && length >= 4 ? length : null;
  }

  Future<bool> verifyAppLockPin(String pin) async {
    final stored = await _secureStorage.read(key: _appLockPinHashKey);
    return stored != null && stored == _hashPin(pin);
  }

  Future<void> resetAll() async {
    await _preferences.remove(_defaultReminderKey);
    await _preferences.remove(_allDayReminderHourKey);
    await _preferences.remove(_allDayReminderMinuteKey);
    await _preferences.remove(_briefingHourKey);
    await _preferences.remove(_briefingMinuteKey);
    await _preferences.remove(_briefingEnabledKey);
    await _preferences.remove(_weekStartsOnMondayKey);
    await _preferences.remove(_showLunarDatesKey);
    await _preferences.remove(_onboardingCompletedKey);
    await _preferences.remove(_aiEnabledKey);
    await _preferences.remove(_aiComplexOnlyKey);
    await _preferences.remove(_blockSensitiveAiKey);
    await _preferences.remove(_categoriesKey);
    await _preferences.remove(_dDayReminderOffsetsKey);
    await _preferences.remove(_appTextSizeKey);
    await _preferences.remove(_legacyCalendarEventTextSizeKey);
    await _preferences.remove(_legacyCalendarDensityKey);
    await _preferences.remove(_defaultCalendarViewKey);
    await _preferences.remove(_hiddenCategoryIdsKey);
    await _preferences.remove(_calendarShowHolidaysKey);
    await _preferences.remove(_calendarDdayOnlyKey);
    await _preferences.remove(_hideSensitiveEventsKey);
    await _preferences.remove(_hideSensitiveNotificationsKey);
    await _preferences.remove(_appLockEnabledKey);
    await _preferences.remove(_appLockBiometricsEnabledKey);
    await _preferences.remove(_use24HourTimeKey);
    await _preferences.remove(_deviceIdKey);
    await deleteDailyAccount();
    await deleteGeminiApiKey();
    await deleteAppLockPin();
  }

  Future<void> _deleteSecureStorageKey(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } on PlatformException catch (error) {
      if (!_isMissingSecureStorageEntitlement(error)) {
        rethrow;
      }
    }
  }

  bool _isMissingSecureStorageEntitlement(PlatformException error) {
    final details = error.details?.toString().toLowerCase() ?? '';
    final message = error.message?.toLowerCase() ?? '';
    final code = error.code.toLowerCase();
    return code.contains('-34018') ||
        details.contains('-34018') ||
        message.contains('-34018') ||
        message.contains('entitlement');
  }

  List<EventCategory> _loadCategories() {
    final raw = _preferences.getString(_categoriesKey);
    if (raw == null || raw.isEmpty) {
      return const [EventCategory.basic, EventCategory.holiday];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [EventCategory.basic, EventCategory.holiday];
      }
      final categories = decoded
          .whereType<Map>()
          .map(
            (item) => EventCategory.fromJson(Map<String, Object?>.from(item)),
          )
          .where((category) => category.id.isNotEmpty)
          .toList();
      if (!categories.any(
        (category) => category.id == EventCategory.holiday.id,
      )) {
        categories.add(EventCategory.holiday);
      }
      return categories;
    } on Object {
      return const [EventCategory.basic, EventCategory.holiday];
    }
  }

  List<int> _loadDdayOffsets() {
    final raw = _preferences.getString(_dDayReminderOffsetsKey);
    if (raw == null || raw.isEmpty) {
      return const [-7, -3, -1, 0];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [-7, -3, -1, 0];
      }
      return decoded.whereType<int>().toList();
    } on Object {
      return const [-7, -3, -1, 0];
    }
  }

  List<String> _loadStringList(String key) {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded.whereType<String>().toList();
    } on Object {
      return const [];
    }
  }

  Future<void> _setNullableString(String key, String? value) async {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _preferences.remove(key);
      return;
    }
    await _preferences.setString(key, trimmed);
  }

  DailyAccount? _storedDailyAccount() {
    final raw = _preferences.getString(_dailyAccountKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return DailyAccount.fromJson(jsonDecode(raw));
    } on Object {
      return null;
    }
  }

  DailyAccount _currentOrNewDailyAccount() {
    return _storedDailyAccount() ??
        DailyAccount(id: const Uuid().v4(), appleAccount: appleAccount());
  }

  Future<void> _saveDailyAccount(DailyAccount account) async {
    if (!account.hasProviders) {
      await _preferences.remove(_dailyAccountKey);
      return;
    }
    await _preferences.setString(
      _dailyAccountKey,
      jsonEncode(account.toJson()),
    );
  }

  String? _stringOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }
}
