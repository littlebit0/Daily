import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/events/domain/calendar_event.dart';
import '../settings/app_settings.dart';
import 'calendar_widget_service.dart';

export 'calendar_widget_service.dart'
    show CalendarWidgetChannelContract, CalendarWidgetService;

/// Compatibility adapter for Apple-specific callers that still use the
/// original service name. Cross-platform code should use
/// [CalendarWidgetService].
class AppleWidgetService extends CalendarWidgetService {
  AppleWidgetService({
    required super.eventRepository,
    required super.settingsRepository,
    MethodChannel channel = const MethodChannel(
      CalendarWidgetChannelContract.appleChannel,
    ),
    super.themeRefreshDelay = const Duration(milliseconds: 400),
  }) : super(channel: channel);

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
}

/// Compatibility name for Apple tests and integrations that reference the
/// original snapshot builder.
abstract final class AppleWidgetSnapshotBuilder {
  static Map<String, Object?> build({
    required DateTime now,
    required AppSettings settings,
    required DateTime gridStart,
    required List<CalendarEvent> monthEvents,
    required List<CalendarEvent> allEvents,
  }) {
    return CalendarWidgetSnapshotBuilder.build(
      now: now,
      settings: settings,
      gridStart: gridStart,
      monthEvents: monthEvents,
      allEvents: allEvents,
    );
  }
}

class AppleWidgetTodoAction extends CalendarWidgetTodoAction {
  const AppleWidgetTodoAction({
    required super.token,
    required super.eventId,
    required super.completed,
  });

  static AppleWidgetTodoAction? fromMap(Map<Object?, Object?> map) {
    final action = CalendarWidgetTodoAction.fromMap(map);
    if (action == null) return null;
    return AppleWidgetTodoAction(
      token: action.token,
      eventId: action.eventId,
      completed: action.completed,
    );
  }
}
