import '../../events/domain/event_draft.dart';

class EventParseResult {
  const EventParseResult({
    this.draft,
    this.question,
    this.usedAi = false,
    this.warnings = const [],
  });

  final EventDraft? draft;
  final String? question;
  final bool usedAi;
  final List<String> warnings;

  bool get hasDraft => draft != null;
}
