import 'package:uuid/uuid.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/time/korea_time.dart';
import '../domain/calendar_event.dart';
import '../domain/event_draft.dart';
import '../domain/event_repository.dart';

class EventCommandService {
  EventCommandService({
    required EventRepository repository,
    required SettingsRepository settingsRepository,
    required NotificationService notificationService,
    required SyncService syncService,
    KoreaTime? clock,
    Uuid? uuid,
  }) : _repository = repository,
       _settingsRepository = settingsRepository,
       _notificationService = notificationService,
       _syncService = syncService,
       _clock = clock ?? const KoreaTime(),
       _uuid = uuid ?? const Uuid();

  final EventRepository _repository;
  final SettingsRepository _settingsRepository;
  final NotificationService _notificationService;
  final SyncService _syncService;
  final KoreaTime _clock;
  final Uuid _uuid;

  Future<CalendarEvent> create(EventDraft draft) async {
    final now = _clock.now();
    final event = draft.toEvent(
      id: _uuid.v4(),
      now: now,
      deviceId: await _settingsRepository.deviceId(),
    );
    await save(event);
    return event;
  }

  Future<void> save(CalendarEvent event) async {
    final updated = event
        .copyWith(updatedAt: _clock.now(), syncStatus: 'pending')
        .normalizeAllDayBounds();
    final existing = await _repository.findById(updated.id);
    await _repository.save(updated);
    await _notificationService.cancelEventReminder(
      updated.id,
      reminderMinutesBeforeList: _combinedReminderMinutes(existing, updated),
    );
    await _notificationService.scheduleEventReminder(
      updated,
      allowImmediate: true,
    );
    await _syncService.queueEventUpsert(updated);
  }

  Future<void> delete(String eventId) async {
    final existing = await _repository.findById(eventId);
    await _repository.delete(eventId);
    await _notificationService.cancelEventReminder(
      eventId,
      reminderMinutesBeforeList:
          existing?.reminderMinutesBeforeList ?? const [],
    );
    await _syncService.queueEventDelete(eventId);
  }

  List<int> _combinedReminderMinutes(
    CalendarEvent? existing,
    CalendarEvent updated,
  ) {
    return normalizeReminderMinutes([
      ...?existing?.reminderMinutesBeforeList,
      ...updated.reminderMinutesBeforeList,
    ]);
  }
}
