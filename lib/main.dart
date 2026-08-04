import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/daily_app.dart';
import 'core/di/app_providers.dart';
import 'core/settings/settings_repository.dart';
import 'core/update/app_update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko');
  final preferences = await SharedPreferences.getInstance();
  final settingsRepository = SettingsRepository(preferences: preferences);

  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
      ],
      child: const DailyApp(),
    ),
  );
  unawaited(AppUpdateService().checkAndInstallIfAvailable());
}
