import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../features/chat/application/gemini_schedule_parser.dart';
import '../../features/chat/application/hybrid_schedule_parser.dart';
import '../../features/chat/application/rule_based_schedule_parser.dart';
import '../../features/chat/domain/schedule_parser.dart';
import '../../features/events/application/event_command_service.dart';
import '../../features/events/data/app_database.dart';
import '../../features/events/data/drift_event_repository.dart';
import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_repository.dart';
import '../calendar/korean_holiday_service.dart';
import '../notifications/local_notification_service.dart';
import '../notifications/notification_service.dart';
import '../settings/app_settings.dart';
import '../settings/settings_repository.dart';
import '../sync/google_drive_auth_service.dart';
import '../sync/google_drive_sync_service.dart';
import '../sync/sync_service.dart';

class CalendarRange {
  const CalendarRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) {
    return other is CalendarRange && start == other.start && end == other.end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError('settingsRepositoryProvider must be overridden');
});

final appSettingsProvider = StateProvider<AppSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).load();
});

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return DriftEventRepository(ref.watch(databaseProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return LocalNotificationService(
    settingsRepository: ref.watch(settingsRepositoryProvider),
  );
});

final koreanHolidayServiceProvider = Provider<KoreanHolidayService>((ref) {
  return KoreanHolidayService();
});

final googleDriveAuthServiceProvider = Provider<GoogleDriveAuthService>((ref) {
  return GoogleDriveAuthService();
});

final googleDriveSyncServiceProvider = Provider<GoogleDriveSyncService>((ref) {
  final service = GoogleDriveSyncService(
    authService: ref.watch(googleDriveAuthServiceProvider),
    eventRepository: ref.watch(eventRepositoryProvider),
    notificationService: ref.watch(notificationServiceProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return ref.watch(googleDriveSyncServiceProvider);
});

final eventCommandServiceProvider = Provider<EventCommandService>((ref) {
  return EventCommandService(
    repository: ref.watch(eventRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
    notificationService: ref.watch(notificationServiceProvider),
    syncService: ref.watch(syncServiceProvider),
  );
});

final scheduleParserProvider = Provider<ScheduleParser>((ref) {
  final settingsRepository = ref.watch(settingsRepositoryProvider);
  return HybridScheduleParser(
    ruleBasedParser: RuleBasedScheduleParser(),
    aiParser: GeminiScheduleParser(settingsRepository),
    settingsRepository: settingsRepository,
  );
});

final visibleMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final calendarViewModeProvider = StateProvider<CalendarViewMode>((ref) {
  return ref.read(appSettingsProvider).defaultCalendarView;
});

final calendarSearchQueryProvider = StateProvider<String>((ref) => '');

final eventsInRangeProvider =
    StreamProvider.family<List<CalendarEvent>, CalendarRange>((ref, range) {
      final holidays = ref
          .watch(koreanHolidayServiceProvider)
          .holidayEventsInRange(range.start, range.end);
      return ref
          .watch(eventRepositoryProvider)
          .watchEventsInRange(range.start, range.end)
          .map((events) {
            return [...events, ...holidays]
              ..sort((a, b) => a.startAt.compareTo(b.startAt));
          });
    });

final eventsForSelectedDateProvider = Provider<AsyncValue<List<CalendarEvent>>>(
  (ref) {
    final selected = ref.watch(selectedDateProvider);
    final start = DateTime(selected.year, selected.month, selected.day);
    final end = start.add(const Duration(days: 1));
    return ref.watch(eventsInRangeProvider(CalendarRange(start, end)));
  },
);

extension DateTimeRangeX on DateTimeRange {
  CalendarRange toCalendarRange() => CalendarRange(start, end);
}
