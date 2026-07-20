import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_category.dart';

enum AppTextSize {
  basic('기본', 0.8),
  large('크게', 1.0);

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
    this.hideSensitiveEvents = false,
    this.hideSensitiveNotifications = false,
    this.appLockEnabled = false,
    this.appLockBiometricsEnabled = false,
    this.use24HourTime = true,
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
  final bool hideSensitiveEvents;
  final bool hideSensitiveNotifications;
  final bool appLockEnabled;
  final bool appLockBiometricsEnabled;
  final bool use24HourTime;

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
    bool? hideSensitiveEvents,
    bool? hideSensitiveNotifications,
    bool? appLockEnabled,
    bool? appLockBiometricsEnabled,
    bool? use24HourTime,
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
      hideSensitiveEvents: hideSensitiveEvents ?? this.hideSensitiveEvents,
      hideSensitiveNotifications:
          hideSensitiveNotifications ?? this.hideSensitiveNotifications,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      appLockBiometricsEnabled:
          appLockBiometricsEnabled ?? this.appLockBiometricsEnabled,
      use24HourTime: use24HourTime ?? this.use24HourTime,
    );
  }
}
