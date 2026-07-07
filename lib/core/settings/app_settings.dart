import '../../features/events/domain/event_category.dart';

enum CalendarDensity {
  relaxed('넓게'),
  standard('기본'),
  dense('많이');

  const CalendarDensity(this.label);

  final String label;

  static CalendarDensity fromName(String? name) {
    return CalendarDensity.values.firstWhere(
      (density) => density.name == name,
      orElse: () => CalendarDensity.standard,
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
  const AppSettings({
    this.defaultReminderMinutes = 60,
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
    this.calendarDensity = CalendarDensity.standard,
    this.defaultCalendarView = CalendarViewMode.week,
    this.hiddenCategoryIds = const <String>[],
    this.calendarShowHolidays = true,
    this.calendarDdayOnly = false,
    this.hideSensitiveEvents = false,
    this.hideSensitiveNotifications = false,
    this.appLockEnabled = false,
    this.use24HourTime = true,
  });

  static const _defaultCategories = <EventCategory>[
    EventCategory.basic,
    EventCategory.holiday,
  ];

  final int defaultReminderMinutes;
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
  final CalendarDensity calendarDensity;
  final CalendarViewMode defaultCalendarView;
  final List<String> hiddenCategoryIds;
  final bool calendarShowHolidays;
  final bool calendarDdayOnly;
  final bool hideSensitiveEvents;
  final bool hideSensitiveNotifications;
  final bool appLockEnabled;
  final bool use24HourTime;

  AppSettings copyWith({
    int? defaultReminderMinutes,
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
    CalendarDensity? calendarDensity,
    CalendarViewMode? defaultCalendarView,
    List<String>? hiddenCategoryIds,
    bool? calendarShowHolidays,
    bool? calendarDdayOnly,
    bool? hideSensitiveEvents,
    bool? hideSensitiveNotifications,
    bool? appLockEnabled,
    bool? use24HourTime,
  }) {
    return AppSettings(
      defaultReminderMinutes:
          defaultReminderMinutes ?? this.defaultReminderMinutes,
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
      calendarDensity: calendarDensity ?? this.calendarDensity,
      defaultCalendarView: defaultCalendarView ?? this.defaultCalendarView,
      hiddenCategoryIds: hiddenCategoryIds ?? this.hiddenCategoryIds,
      calendarShowHolidays: calendarShowHolidays ?? this.calendarShowHolidays,
      calendarDdayOnly: calendarDdayOnly ?? this.calendarDdayOnly,
      hideSensitiveEvents: hideSensitiveEvents ?? this.hideSensitiveEvents,
      hideSensitiveNotifications:
          hideSensitiveNotifications ?? this.hideSensitiveNotifications,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      use24HourTime: use24HourTime ?? this.use24HourTime,
    );
  }
}
