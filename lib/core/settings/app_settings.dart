import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_category.dart';

enum AppThemeMode {
  system('자동'),
  light('화이트'),
  dark('다크');

  const AppThemeMode(this.label);

  final String label;

  static AppThemeMode fromName(String? name) {
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => AppThemeMode.system,
    );
  }
}

enum MonthNavigationMode {
  horizontal('좌우 슬라이드'),
  vertical('상하 스크롤');

  const MonthNavigationMode(this.label);

  final String label;

  static MonthNavigationMode fromName(String? name) {
    return MonthNavigationMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => MonthNavigationMode.horizontal,
    );
  }
}

enum AppTextSize {
  basic('기본', 0.8),
  large('크게', 1.0),
  extraLarge('더 크게', 1.15);

  const AppTextSize(this.label, this.scale);

  final String label;
  final double scale;

  static AppTextSize fromName(String? name) {
    return AppTextSize.values.firstWhere(
      (size) => size.name == name,
      orElse: () => AppTextSize.basic,
    );
  }
}

enum CalendarViewMode {
  week('주간'),
  month('월간'),
  day('일간');

  const CalendarViewMode(this.label);

  final String label;

  static CalendarViewMode fromName(String? name) {
    return CalendarViewMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => CalendarViewMode.week,
    );
  }
}

enum AppLockMethod {
  noPin('PIN 없이 잠금'),
  appPin('PIN 잠금'),
  system('시스템 잠금 비밀번호');

  const AppLockMethod(this.label);

  final String label;

  static AppLockMethod fromName(
    String? name, {
    bool legacyBiometricsEnabled = false,
  }) {
    return AppLockMethod.values.firstWhere(
      (method) => method.name == name,
      orElse: () =>
          legacyBiometricsEnabled ? AppLockMethod.system : AppLockMethod.appPin,
    );
  }
}

class AppSettings {
  AppSettings({
    int? defaultReminderMinutes = 60,
    List<int>? defaultReminderMinutesList,
    this.allDayReminderHour = 9,
    this.allDayReminderMinute = 0,
    this.morningBriefingHour = 8,
    this.morningBriefingMinute = 0,
    this.morningBriefingEnabled = true,
    this.weekStartsOnMonday = false,
    this.showLunarDates = true,
    this.showAdjacentMonthDates = true,
    this.onboardingCompleted = false,
    this.aiEnabled = false,
    this.aiOnlyForComplexInput = true,
    this.blockSensitiveAi = true,
    this.categories = _defaultCategories,
    this.dDayReminderOffsets = const [-7, -3, -1, 0],
    this.appTextSize = AppTextSize.basic,
    this.defaultCalendarView = CalendarViewMode.week,
    this.hiddenCategoryIds = const <String>[],
    this.calendarShowHolidays = true,
    this.calendarDdayOnly = false,
    this.appLockEnabled = false,
    this.appLockBiometricsEnabled = false,
    this.appLockMethod = AppLockMethod.noPin,
    this.use24HourTime = true,
    this.themeMode = AppThemeMode.system,
    this.monthNavigationMode = MonthNavigationMode.horizontal,
  }) : defaultReminderMinutesList = normalizeReminderMinutes(
         defaultReminderMinutesList ??
             (defaultReminderMinutes == null
                 ? const <int>[]
                 : <int>[defaultReminderMinutes]),
       );

  static const _defaultCategories = <EventCategory>[
    EventCategory.basic,
    EventCategory.holiday,
  ];

  final List<int> defaultReminderMinutesList;
  int get defaultReminderMinutes => defaultReminderMinutesList.isEmpty
      ? 60
      : defaultReminderMinutesList.first;
  final int allDayReminderHour;
  final int allDayReminderMinute;
  final int morningBriefingHour;
  final int morningBriefingMinute;
  final bool morningBriefingEnabled;
  final bool weekStartsOnMonday;
  final bool showLunarDates;
  final bool showAdjacentMonthDates;
  final bool onboardingCompleted;
  final bool aiEnabled;
  final bool aiOnlyForComplexInput;
  final bool blockSensitiveAi;
  final List<EventCategory> categories;
  final List<int> dDayReminderOffsets;
  final AppTextSize appTextSize;
  final CalendarViewMode defaultCalendarView;
  final List<String> hiddenCategoryIds;
  final bool calendarShowHolidays;
  final bool calendarDdayOnly;
  final bool appLockEnabled;
  final bool appLockBiometricsEnabled;
  final AppLockMethod appLockMethod;
  final bool use24HourTime;
  final AppThemeMode themeMode;
  final MonthNavigationMode monthNavigationMode;

  AppSettings copyWith({
    int? defaultReminderMinutes,
    List<int>? defaultReminderMinutesList,
    int? allDayReminderHour,
    int? allDayReminderMinute,
    int? morningBriefingHour,
    int? morningBriefingMinute,
    bool? morningBriefingEnabled,
    bool? weekStartsOnMonday,
    bool? showLunarDates,
    bool? showAdjacentMonthDates,
    bool? onboardingCompleted,
    bool? aiEnabled,
    bool? aiOnlyForComplexInput,
    bool? blockSensitiveAi,
    List<EventCategory>? categories,
    List<int>? dDayReminderOffsets,
    AppTextSize? appTextSize,
    CalendarViewMode? defaultCalendarView,
    List<String>? hiddenCategoryIds,
    bool? calendarShowHolidays,
    bool? calendarDdayOnly,
    bool? appLockEnabled,
    bool? appLockBiometricsEnabled,
    AppLockMethod? appLockMethod,
    bool? use24HourTime,
    AppThemeMode? themeMode,
    MonthNavigationMode? monthNavigationMode,
  }) {
    return AppSettings(
      defaultReminderMinutesList:
          defaultReminderMinutesList ??
          (defaultReminderMinutes == null
              ? this.defaultReminderMinutesList
              : <int>[defaultReminderMinutes]),
      allDayReminderHour: allDayReminderHour ?? this.allDayReminderHour,
      allDayReminderMinute: allDayReminderMinute ?? this.allDayReminderMinute,
      morningBriefingHour: morningBriefingHour ?? this.morningBriefingHour,
      morningBriefingMinute:
          morningBriefingMinute ?? this.morningBriefingMinute,
      morningBriefingEnabled:
          morningBriefingEnabled ?? this.morningBriefingEnabled,
      weekStartsOnMonday: weekStartsOnMonday ?? this.weekStartsOnMonday,
      showLunarDates: showLunarDates ?? this.showLunarDates,
      showAdjacentMonthDates:
          showAdjacentMonthDates ?? this.showAdjacentMonthDates,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      aiOnlyForComplexInput:
          aiOnlyForComplexInput ?? this.aiOnlyForComplexInput,
      blockSensitiveAi: blockSensitiveAi ?? this.blockSensitiveAi,
      categories: categories ?? this.categories,
      dDayReminderOffsets: dDayReminderOffsets ?? this.dDayReminderOffsets,
      appTextSize: appTextSize ?? this.appTextSize,
      defaultCalendarView: defaultCalendarView ?? this.defaultCalendarView,
      hiddenCategoryIds: hiddenCategoryIds ?? this.hiddenCategoryIds,
      calendarShowHolidays: calendarShowHolidays ?? this.calendarShowHolidays,
      calendarDdayOnly: calendarDdayOnly ?? this.calendarDdayOnly,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      appLockBiometricsEnabled:
          appLockBiometricsEnabled ?? this.appLockBiometricsEnabled,
      appLockMethod: appLockMethod ?? this.appLockMethod,
      use24HourTime: use24HourTime ?? this.use24HourTime,
      themeMode: themeMode ?? this.themeMode,
      monthNavigationMode: monthNavigationMode ?? this.monthNavigationMode,
    );
  }
}
