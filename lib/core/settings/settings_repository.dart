import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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
  static const _calendarDensityKey = 'calendarDensity';
  static const _defaultCalendarViewKey = 'defaultCalendarView';
  static const _hiddenCategoryIdsKey = 'hiddenCategoryIds';
  static const _calendarShowHolidaysKey = 'calendarShowHolidays';
  static const _calendarDdayOnlyKey = 'calendarDdayOnly';
  static const _hideSensitiveEventsKey = 'hideSensitiveEvents';
  static const _hideSensitiveNotificationsKey = 'hideSensitiveNotifications';
  static const _appLockEnabledKey = 'appLockEnabled';
  static const _deviceIdKey = 'deviceId';
  static const _geminiKey = 'geminiApiKey';
  static const _appLockPinHashKey = 'appLockPinHash';

  AppSettings load() {
    return AppSettings(
      defaultReminderMinutes: _preferences.getInt(_defaultReminderKey) ?? 60,
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
      calendarDensity: CalendarDensity.fromName(
        _preferences.getString(_calendarDensityKey),
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
    );
  }

  Future<void> save(AppSettings settings) async {
    await _preferences.setInt(
      _defaultReminderKey,
      settings.defaultReminderMinutes,
    );
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
    await _preferences.setString(
      _calendarDensityKey,
      settings.calendarDensity.name,
    );
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

  Future<String?> geminiApiKey() {
    return _secureStorage.read(key: _geminiKey);
  }

  Future<void> saveGeminiApiKey(String value) {
    return _secureStorage.write(key: _geminiKey, value: value.trim());
  }

  Future<void> deleteGeminiApiKey() {
    return _secureStorage.delete(key: _geminiKey);
  }

  Future<void> saveAppLockPin(String pin) {
    return _secureStorage.write(key: _appLockPinHashKey, value: _hashPin(pin));
  }

  Future<void> deleteAppLockPin() {
    return _secureStorage.delete(key: _appLockPinHashKey);
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
    await _preferences.remove(_calendarDensityKey);
    await _preferences.remove(_defaultCalendarViewKey);
    await _preferences.remove(_hiddenCategoryIdsKey);
    await _preferences.remove(_calendarShowHolidaysKey);
    await _preferences.remove(_calendarDdayOnlyKey);
    await _preferences.remove(_hideSensitiveEventsKey);
    await _preferences.remove(_hideSensitiveNotificationsKey);
    await _preferences.remove(_appLockEnabledKey);
    await _preferences.remove(_deviceIdKey);
    await deleteGeminiApiKey();
    await deleteAppLockPin();
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

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }
}
