class AppSettings {
  const AppSettings({
    this.defaultReminderMinutes = 60,
    this.morningBriefingHour = 8,
    this.morningBriefingMinute = 0,
    this.aiEnabled = false,
    this.aiOnlyForComplexInput = true,
    this.blockSensitiveAi = true,
  });

  final int defaultReminderMinutes;
  final int morningBriefingHour;
  final int morningBriefingMinute;
  final bool aiEnabled;
  final bool aiOnlyForComplexInput;
  final bool blockSensitiveAi;

  AppSettings copyWith({
    int? defaultReminderMinutes,
    int? morningBriefingHour,
    int? morningBriefingMinute,
    bool? aiEnabled,
    bool? aiOnlyForComplexInput,
    bool? blockSensitiveAi,
  }) {
    return AppSettings(
      defaultReminderMinutes:
          defaultReminderMinutes ?? this.defaultReminderMinutes,
      morningBriefingHour: morningBriefingHour ?? this.morningBriefingHour,
      morningBriefingMinute:
          morningBriefingMinute ?? this.morningBriefingMinute,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      aiOnlyForComplexInput:
          aiOnlyForComplexInput ?? this.aiOnlyForComplexInput,
      blockSensitiveAi: blockSensitiveAi ?? this.blockSensitiveAi,
    );
  }
}
