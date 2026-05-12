import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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
  static const _briefingHourKey = 'morningBriefingHour';
  static const _briefingMinuteKey = 'morningBriefingMinute';
  static const _aiEnabledKey = 'aiEnabled';
  static const _aiComplexOnlyKey = 'aiOnlyForComplexInput';
  static const _blockSensitiveAiKey = 'blockSensitiveAi';
  static const _deviceIdKey = 'deviceId';
  static const _geminiKey = 'geminiApiKey';

  AppSettings load() {
    return AppSettings(
      defaultReminderMinutes: _preferences.getInt(_defaultReminderKey) ?? 60,
      morningBriefingHour: _preferences.getInt(_briefingHourKey) ?? 8,
      morningBriefingMinute: _preferences.getInt(_briefingMinuteKey) ?? 0,
      aiEnabled: _preferences.getBool(_aiEnabledKey) ?? false,
      aiOnlyForComplexInput: _preferences.getBool(_aiComplexOnlyKey) ?? true,
      blockSensitiveAi: _preferences.getBool(_blockSensitiveAiKey) ?? true,
    );
  }

  Future<void> save(AppSettings settings) async {
    await _preferences.setInt(
      _defaultReminderKey,
      settings.defaultReminderMinutes,
    );
    await _preferences.setInt(_briefingHourKey, settings.morningBriefingHour);
    await _preferences.setInt(
      _briefingMinuteKey,
      settings.morningBriefingMinute,
    );
    await _preferences.setBool(_aiEnabledKey, settings.aiEnabled);
    await _preferences.setBool(
      _aiComplexOnlyKey,
      settings.aiOnlyForComplexInput,
    );
    await _preferences.setBool(_blockSensitiveAiKey, settings.blockSensitiveAi);
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
}
