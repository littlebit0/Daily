import '../../../core/settings/settings_repository.dart';
import '../domain/event_parse_result.dart';
import '../domain/schedule_parser.dart';

class HybridScheduleParser implements ScheduleParser {
  HybridScheduleParser({
    required ScheduleParser ruleBasedParser,
    required ScheduleParser aiParser,
    required SettingsRepository settingsRepository,
  }) : _ruleBasedParser = ruleBasedParser,
       _aiParser = aiParser,
       _settingsRepository = settingsRepository;

  final ScheduleParser _ruleBasedParser;
  final ScheduleParser _aiParser;
  final SettingsRepository _settingsRepository;

  @override
  Future<EventParseResult> parse(
    String input, {
    required DateTime baseDate,
    DateTime? selectedDate,
    required int defaultReminderMinutes,
    List<int>? defaultReminderMinutesList,
  }) async {
    final settings = _settingsRepository.load();
    final ruleResult = await _ruleBasedParser.parse(
      input,
      baseDate: baseDate,
      selectedDate: selectedDate,
      defaultReminderMinutes: defaultReminderMinutes,
      defaultReminderMinutesList: defaultReminderMinutesList,
    );

    if (ruleResult.hasDraft && (!_looksComplex(input) || !settings.aiEnabled)) {
      return ruleResult;
    }

    if (!settings.aiEnabled || _isSensitive(input, settings.blockSensitiveAi)) {
      return ruleResult;
    }

    final aiResult = await _aiParser.parse(
      input,
      baseDate: baseDate,
      selectedDate: selectedDate,
      defaultReminderMinutes: defaultReminderMinutes,
      defaultReminderMinutesList: defaultReminderMinutesList,
    );

    return aiResult.hasDraft ? aiResult : ruleResult;
  }

  bool _looksComplex(String input) {
    return input.length > 30 ||
        input.contains('쯤') ||
        input.contains('이후') ||
        input.contains('전에') ||
        input.contains('가능하면') ||
        input.contains('아무때나');
  }

  bool _isSensitive(String input, bool blockSensitiveAi) {
    if (!blockSensitiveAi) {
      return false;
    }
    const keywords = ['비밀번호', '주민번호', '계좌', '카드번호', '민감', '비밀'];
    return keywords.any(input.contains);
  }
}
