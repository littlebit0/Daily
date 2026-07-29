import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../features/events/application/event_command_service.dart';
import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_category.dart';
import '../../features/events/domain/event_repository.dart';
import '../../features/events/domain/recurrence_rule.dart';
import '../settings/settings_repository.dart';
import 'calendar_import_models.dart';
import 'google_calendar_source.dart';
import 'native_calendar_source.dart';

class CalendarImportService {
  CalendarImportService({
    required NativeCalendarSource nativeSource,
    required GoogleCalendarSource googleSource,
    required EventRepository eventRepository,
    required EventCommandService eventCommandService,
    required SettingsRepository settingsRepository,
  }) : _nativeSource = nativeSource,
       _googleSource = googleSource,
       _eventRepository = eventRepository,
       _eventCommandService = eventCommandService,
       _settingsRepository = settingsRepository;

  final NativeCalendarSource _nativeSource;
  final GoogleCalendarSource _googleSource;
  final EventRepository _eventRepository;
  final EventCommandService _eventCommandService;
  final SettingsRepository _settingsRepository;

  NativeCalendarSource get nativeSource => _nativeSource;

  Future<List<ImportableCalendar>> listNativeCalendars() =>
      _nativeSource.listCalendars();

  Future<List<ImportableCalendar>> listGoogleCalendars() =>
      _googleSource.listCalendars();

  Future<CalendarImportResult> importCalendars(
    Iterable<ImportableCalendar> calendars,
  ) async {
    final selected = calendars.toList(growable: false);
    final categoriesByCalendar = await _ensureImportedCategories(selected);
    final nativeCalendars = selected
        .where((calendar) => calendar.provider != CalendarImportProvider.google)
        .toList(growable: false);
    final googleCalendars = selected
        .where((calendar) => calendar.provider == CalendarImportProvider.google)
        .toList(growable: false);
    final events = <ExternalCalendarEvent>[
      ...await _nativeSource.loadEvents(nativeCalendars),
      ...await _googleSource.loadEvents(googleCalendars),
    ];

    var skipped = 0;
    final now = DateTime.now();
    final deviceId = await _settingsRepository.deviceId();
    final pending = <CalendarEvent>[];
    for (final external in events) {
      try {
        final id = externalEventId(external);
        if (await _eventRepository.findById(id) != null) {
          skipped += 1;
          continue;
        }
        final event = CalendarEvent(
          id: id,
          title: external.title,
          memo: external.memo,
          location: external.location,
          url: external.url,
          startAt: external.startAt,
          endAt: external.endAt,
          allDay: external.allDay,
          category:
              categoriesByCalendar[_calendarKey(
                external.provider,
                external.calendarId,
              )] ??
              EventCategory.basic,
          colorValue:
              categoriesByCalendar[_calendarKey(
                    external.provider,
                    external.calendarId,
                  )]
                  ?.colorValue ??
              external.colorValue ??
              EventCategory.basic.colorValue,
          reminderMinutesBeforeList: external.reminderMinutesBeforeList,
          recurrence: recurrenceFromRrule(external.recurrenceRule),
          createdAt: now,
          updatedAt: now,
          deviceId: deviceId,
          syncStatus: 'pending',
        );
        pending.add(event);
      } on Object {
        // Invalid source records are counted after the valid batch is saved.
      }
    }
    final importedIds = await _eventCommandService.importBatch(pending);
    final invalid = events.length - skipped - pending.length;
    return CalendarImportResult(
      imported: importedIds.length,
      skipped: skipped,
      failed: invalid + pending.length - importedIds.length,
    );
  }

  Future<Map<String, EventCategory>> _ensureImportedCategories(
    List<ImportableCalendar> calendars,
  ) async {
    final settings = _settingsRepository.load();
    final existingById = {
      for (final category in settings.categories) category.id: category,
    };
    final imported = <String, EventCategory>{};
    final replacements = <String, EventCategory>{};
    for (final calendar in calendars) {
      final categoryId = importedCategoryId(calendar);
      final category =
          existingById[categoryId] ??
          EventCategory(
            id: categoryId,
            label: calendar.title.trim().isEmpty
                ? calendar.provider.label
                : calendar.title.trim(),
            colorValue: calendar.colorValue ?? EventCategory.basic.colorValue,
          );
      imported[_calendarKey(calendar.provider, calendar.id)] = category;
      replacements[category.id] = category;
    }
    if (replacements.isEmpty) {
      return imported;
    }

    final categories = <EventCategory>[
      for (final category in settings.categories)
        if (!replacements.containsKey(category.id) &&
            category.id != EventCategory.holiday.id)
          category,
      ...replacements.values,
      EventCategory.holiday,
    ];
    final changed =
        categories.length != settings.categories.length ||
        List.generate(categories.length, (index) => index).any(
          (index) =>
              categories[index].id != settings.categories[index].id ||
              categories[index].label != settings.categories[index].label ||
              categories[index].colorValue !=
                  settings.categories[index].colorValue,
        );
    if (changed) {
      await _settingsRepository.save(settings.copyWith(categories: categories));
    }
    return imported;
  }

  static String importedCategoryId(ImportableCalendar calendar) {
    final value = _calendarKey(calendar.provider, calendar.id);
    return 'import_${sha256.convert(utf8.encode(value)).toString().substring(0, 16)}';
  }

  static String _calendarKey(
    CalendarImportProvider provider,
    String calendarId,
  ) => '${provider.name}:$calendarId';

  static String externalEventId(ExternalCalendarEvent event) {
    final value = [
      'daily-calendar-import-v1',
      event.provider.name,
      event.calendarId,
      event.sourceId,
    ].join('\u001f');
    final hex = sha256.convert(utf8.encode(value)).toString().substring(0, 32);
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  static RecurrenceRule recurrenceFromRrule(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return const RecurrenceRule();
    }
    final body = value.startsWith('RRULE:') ? value.substring(6) : value;
    final fields = <String, String>{};
    for (final field in body.split(';')) {
      final separator = field.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      fields[field.substring(0, separator).toUpperCase()] = field.substring(
        separator + 1,
      );
    }
    final frequency = switch (fields['FREQ']?.toUpperCase()) {
      'DAILY' => RecurrenceFrequency.daily,
      'WEEKLY' => RecurrenceFrequency.weekly,
      'MONTHLY' => RecurrenceFrequency.monthly,
      'YEARLY' => RecurrenceFrequency.yearly,
      _ => RecurrenceFrequency.none,
    };
    if (frequency == RecurrenceFrequency.none) {
      return const RecurrenceRule();
    }
    final interval = int.tryParse(fields['INTERVAL'] ?? '') ?? 1;
    final count = int.tryParse(fields['COUNT'] ?? '');
    return RecurrenceRule(
      frequency: frequency,
      interval: interval < 1 ? 1 : interval,
      until: _rruleDate(fields['UNTIL']),
      count: count != null && count > 0 ? count : null,
    );
  }

  static DateTime? _rruleDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value.length == 8) {
      final year = int.tryParse(value.substring(0, 4));
      final month = int.tryParse(value.substring(4, 6));
      final day = int.tryParse(value.substring(6, 8));
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z?$',
    ).firstMatch(value);
    if (match == null) {
      return null;
    }
    final values = [
      for (var index = 1; index <= 6; index++) int.parse(match[index]!),
    ];
    final date = DateTime.utc(
      values[0],
      values[1],
      values[2],
      values[3],
      values[4],
      values[5],
    );
    return value.endsWith('Z') ? date.toLocal() : date;
  }
}
