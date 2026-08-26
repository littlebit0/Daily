import 'package:daily/core/calendar_import/calendar_import_models.dart';
import 'package:daily/core/calendar_import/calendar_import_service.dart';
import 'package:daily/core/calendar_import/google_calendar_source.dart';
import 'package:daily/core/calendar_import/native_calendar_source.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalendarImportService.externalEventId', () {
    ExternalCalendarEvent event({
      String sourceId = 'event-1',
      String calendarId = 'calendar-1',
      CalendarImportProvider provider = CalendarImportProvider.google,
    }) {
      return ExternalCalendarEvent(
        sourceId: sourceId,
        calendarId: calendarId,
        provider: provider,
        title: '일정',
        startAt: DateTime(2026, 7, 29, 9),
        endAt: DateTime(2026, 7, 29, 10),
        allDay: false,
      );
    }

    test('같은 외부 일정은 항상 같은 Daily ID를 만든다', () {
      expect(
        CalendarImportService.externalEventId(event()),
        CalendarImportService.externalEventId(event()),
      );
    });

    test('공급자, 캘린더 또는 원본 ID가 다르면 Daily ID도 다르다', () {
      final base = CalendarImportService.externalEventId(event());
      expect(
        CalendarImportService.externalEventId(
          event(provider: CalendarImportProvider.apple),
        ),
        isNot(base),
      );
      expect(
        CalendarImportService.externalEventId(event(calendarId: 'other')),
        isNot(base),
      );
      expect(
        CalendarImportService.externalEventId(event(sourceId: 'other')),
        isNot(base),
      );
    });
  });

  test('가져온 캘린더 분류 ID는 공급자와 원본 캘린더별로 안정적이다', () {
    const apple = ImportableCalendar(
      id: 'calendar-1',
      title: '회사',
      provider: CalendarImportProvider.apple,
      colorValue: 0xff123456,
    );
    const google = ImportableCalendar(
      id: 'calendar-1',
      title: '회사',
      provider: CalendarImportProvider.google,
      colorValue: 0xff123456,
    );

    expect(
      CalendarImportService.importedCategoryId(apple),
      CalendarImportService.importedCategoryId(apple),
    );
    expect(
      CalendarImportService.importedCategoryId(apple),
      isNot(CalendarImportService.importedCategoryId(google)),
    );
  });

  group('CalendarImportService.recurrenceFromRrule', () {
    test('빈 값은 반복 없음으로 변환한다', () {
      expect(
        CalendarImportService.recurrenceFromRrule(null).frequency,
        RecurrenceFrequency.none,
      );
    });

    test('주간 반복의 간격과 횟수를 보존한다', () {
      final rule = CalendarImportService.recurrenceFromRrule(
        'RRULE:FREQ=WEEKLY;INTERVAL=2;COUNT=8',
      );
      expect(rule.frequency, RecurrenceFrequency.weekly);
      expect(rule.interval, 2);
      expect(rule.count, 8);
    });

    test('UTC 종료 시각을 로컬 DateTime으로 변환한다', () {
      final rule = CalendarImportService.recurrenceFromRrule(
        'FREQ=DAILY;UNTIL=20260731T000000Z',
      );
      expect(rule.frequency, RecurrenceFrequency.daily);
      expect(rule.until, DateTime.utc(2026, 7, 31).toLocal());
    });
  });

  test(
    'imported category save preserves a concurrent unrelated setting change',
    () async {
      SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = _ConcurrentImportSettingsRepository(
        preferences: preferences,
      )..injectThemeChangeBeforeNextSave();
      final eventRepository = _UnusedEventRepository();
      final service = CalendarImportService(
        nativeSource: _EmptyNativeCalendarSource(),
        googleSource: GoogleCalendarSource(
          authService: GoogleDriveAuthService(useDesktopOAuth: false),
        ),
        eventRepository: eventRepository,
        eventCommandService: EventCommandService(
          repository: eventRepository,
          settingsRepository: settingsRepository,
          notificationService: _UnusedNotificationService(),
          syncService: _UnusedSyncService(),
        ),
        settingsRepository: settingsRepository,
      );
      const calendar = ImportableCalendar(
        id: 'work-calendar',
        title: 'Work',
        provider: CalendarImportProvider.samsung,
        colorValue: 0xff123456,
      );

      final result = await service.importCalendars(const [calendar]);

      expect(result.imported, 0);
      expect(result.failed, 0);
      expect(settingsRepository.capturedChangedFrom, isNotNull);
      expect(settingsRepository.load().themeMode, AppThemeMode.dark);
      expect(
        settingsRepository.load().categories.any(
          (category) =>
              category.id == CalendarImportService.importedCategoryId(calendar),
        ),
        isTrue,
      );
    },
  );
}

class _EmptyNativeCalendarSource extends NativeCalendarSource {
  @override
  Future<List<ExternalCalendarEvent>> loadEvents(
    Iterable<ImportableCalendar> calendars,
  ) async => const [];
}

class _ConcurrentImportSettingsRepository extends SettingsRepository {
  _ConcurrentImportSettingsRepository({required super.preferences});

  var _injectThemeChange = false;
  AppSettings? capturedChangedFrom;

  void injectThemeChangeBeforeNextSave() {
    capturedChangedFrom = null;
    _injectThemeChange = true;
  }

  @override
  Future<void> save(
    AppSettings settings, {
    bool markSyncPending = true,
    AppSettings? changedFrom,
  }) async {
    if (_injectThemeChange) {
      _injectThemeChange = false;
      capturedChangedFrom = changedFrom;
      final concurrentBase = load();
      await super.save(
        concurrentBase.copyWith(themeMode: AppThemeMode.dark),
        markSyncPending: false,
        changedFrom: concurrentBase,
      );
    }
    await super.save(
      settings,
      markSyncPending: markSyncPending,
      changedFrom: changedFrom,
    );
  }
}

class _UnusedEventRepository implements EventRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} was not expected');
}

class _UnusedNotificationService implements NotificationService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} was not expected');
}

class _UnusedSyncService implements SyncService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} was not expected');
}
