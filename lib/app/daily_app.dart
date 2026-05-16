import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/app_providers.dart';
import '../features/calendar/presentation/month_calendar_page.dart';
import '../features/onboarding/presentation/welcome_page.dart';
import 'daily_theme.dart';

class DailyApp extends ConsumerStatefulWidget {
  const DailyApp({super.key});

  @override
  ConsumerState<DailyApp> createState() => _DailyAppState();
}

class _DailyAppState extends ConsumerState<DailyApp> {
  var _postOnboardingStarted = false;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    final settings = ref.watch(appSettingsProvider);
    if (settings.onboardingCompleted) {
      _startPostOnboardingServices();
    } else {
      _postOnboardingStarted = false;
    }

    return MaterialApp(
      title: 'Daily',
      debugShowCheckedModeBanner: false,
      theme: DailyTheme.light(),
      home: settings.onboardingCompleted
          ? const MonthCalendarPage()
          : const WelcomePage(),
    );
  }

  void _startPostOnboardingServices() {
    if (_postOnboardingStarted) {
      return;
    }
    _postOnboardingStarted = true;
    unawaited(
      Future.microtask(() async {
        await ref.read(syncServiceProvider).start();
      }).catchError((_) {}),
    );
  }
}
