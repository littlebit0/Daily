import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/app_providers.dart';
import '../features/calendar/presentation/month_calendar_page.dart';
import 'daily_theme.dart';

class DailyApp extends ConsumerStatefulWidget {
  const DailyApp({super.key});

  @override
  ConsumerState<DailyApp> createState() => _DailyAppState();
}

class _DailyAppState extends ConsumerState<DailyApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final settings = ref.read(appSettingsProvider);
      await ref.read(notificationServiceProvider).initialize();
      await ref
          .read(notificationServiceProvider)
          .scheduleMorningBriefing(
            hour: settings.morningBriefingHour,
            minute: settings.morningBriefingMinute,
          );
      await ref.read(syncServiceProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    return MaterialApp(
      title: 'Daily',
      debugShowCheckedModeBanner: false,
      theme: DailyTheme.light(),
      home: const MonthCalendarPage(),
    );
  }
}
