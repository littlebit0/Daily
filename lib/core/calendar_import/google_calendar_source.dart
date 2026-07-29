import 'dart:convert';

import 'package:http/http.dart' as http;

import '../sync/google_drive_auth_service.dart';
import 'calendar_import_models.dart';

class GoogleCalendarSource {
  GoogleCalendarSource({
    required GoogleDriveAuthService authService,
    http.Client? httpClient,
  }) : _authService = authService,
       _httpClient = httpClient ?? http.Client();

  static const _scope = GoogleDriveAuthService.calendarReadonlyScope;

  final GoogleDriveAuthService _authService;
  final http.Client _httpClient;

  Future<List<ImportableCalendar>> listCalendars() async {
    late Map<String, String> headers;
    try {
      headers = await _headers(promptIfNecessary: false);
    } on CalendarImportException {
      headers = await _headers(promptIfNecessary: true);
    }
    var response = await _getCalendarList(headers);
    if (_needsAdditionalAuthorization(response)) {
      headers = await _headers(promptIfNecessary: true);
      response = await _getCalendarList(headers);
    }
    _ensureSuccess(response);

    final calendars = <ImportableCalendar>[];
    String? pageToken;
    do {
      final pageResponse = pageToken == null
          ? response
          : await _getCalendarList(headers, pageToken: pageToken);
      _ensureSuccess(pageResponse);
      final body = _jsonMap(pageResponse.body);
      for (final item in (body['items'] as List<Object?>? ?? const [])) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final id = item['id'] as String?;
        final title =
            item['summaryOverride'] as String? ?? item['summary'] as String?;
        if (id == null || id.isEmpty || title == null || title.trim().isEmpty) {
          continue;
        }
        calendars.add(
          ImportableCalendar(
            id: id,
            title: title.trim(),
            provider: CalendarImportProvider.google,
            accountName: item['primary'] == true
                ? _authService.currentAccount?.email
                : null,
            colorValue: _parseGoogleColor(item['backgroundColor'] as String?),
            defaultReminderMinutes: _googleReminderMinutes(
              item['defaultReminders'],
            ),
          ),
        );
      }
      pageToken = body['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);
    return calendars;
  }

  Future<List<ExternalCalendarEvent>> loadEvents(
    Iterable<ImportableCalendar> calendars,
  ) async {
    final selected = calendars
        .where((calendar) => calendar.provider == CalendarImportProvider.google)
        .toList(growable: false);
    if (selected.isEmpty) {
      return const [];
    }
    late Map<String, String> headers;
    try {
      headers = await _headers(promptIfNecessary: false);
    } on CalendarImportException {
      headers = await _headers(promptIfNecessary: true);
    }
    final events = <ExternalCalendarEvent>[];
    for (final calendar in selected) {
      String? pageToken;
      do {
        var response = await _getEvents(
          calendar.id,
          headers,
          pageToken: pageToken,
        );
        if (_needsAdditionalAuthorization(response)) {
          headers = await _headers(promptIfNecessary: true);
          response = await _getEvents(
            calendar.id,
            headers,
            pageToken: pageToken,
          );
        }
        _ensureSuccess(response);
        final body = _jsonMap(response.body);
        for (final item in (body['items'] as List<Object?>? ?? const [])) {
          if (item is! Map<String, dynamic> || item['status'] == 'cancelled') {
            continue;
          }
          final event = _eventFromJson(calendar, item);
          if (event != null) {
            events.add(event);
          }
        }
        pageToken = body['nextPageToken'] as String?;
      } while (pageToken != null && pageToken.isNotEmpty);
    }
    return events;
  }

  Future<Map<String, String>> _headers({
    required bool promptIfNecessary,
  }) async {
    try {
      final headers = await _authService.authorizationHeadersForScopes(const [
        _scope,
      ], promptIfNecessary: promptIfNecessary);
      if (headers == null || headers.isEmpty) {
        throw const CalendarImportException('Google 계정 로그인이 필요합니다.');
      }
      return headers;
    } on GoogleDriveAuthException catch (error) {
      throw CalendarImportException(
        error.message.replaceAll('Google Drive', 'Google Calendar'),
      );
    }
  }

  Future<http.Response> _getCalendarList(
    Map<String, String> headers, {
    String? pageToken,
  }) {
    final query = <String, String>{'maxResults': '250'};
    if (pageToken != null) {
      query['pageToken'] = pageToken;
    }
    return _httpClient.get(
      Uri.https(
        'www.googleapis.com',
        '/calendar/v3/users/me/calendarList',
        query,
      ),
      headers: headers,
    );
  }

  Future<http.Response> _getEvents(
    String calendarId,
    Map<String, String> headers, {
    String? pageToken,
  }) {
    final query = <String, String>{
      'maxResults': '2500',
      'showDeleted': 'false',
      'singleEvents': 'false',
    };
    if (pageToken != null) {
      query['pageToken'] = pageToken;
    }
    return _httpClient.get(
      Uri(
        scheme: 'https',
        host: 'www.googleapis.com',
        pathSegments: ['calendar', 'v3', 'calendars', calendarId, 'events'],
        queryParameters: query,
      ),
      headers: headers,
    );
  }

  ExternalCalendarEvent? _eventFromJson(
    ImportableCalendar calendar,
    Map<String, dynamic> json,
  ) {
    final id = json['id'] as String?;
    final startValue = json['start'];
    final endValue = json['end'];
    if (id == null ||
        id.isEmpty ||
        startValue is! Map<String, dynamic> ||
        endValue is! Map<String, dynamic>) {
      return null;
    }
    final allDay = startValue['date'] is String;
    final start = _googleDate(startValue, allDay: allDay);
    final end = _googleDate(endValue, allDay: allDay);
    if (start == null || end == null) {
      return null;
    }
    final recurrenceValues = json['recurrence'] as List<Object?>?;
    final recurrenceRule = recurrenceValues?.whereType<String>().firstWhere(
      (value) => value.startsWith('RRULE:'),
      orElse: () => '',
    );
    return ExternalCalendarEvent(
      sourceId: id,
      calendarId: calendar.id,
      provider: CalendarImportProvider.google,
      title: ((json['summary'] as String?)?.trim().isNotEmpty ?? false)
          ? (json['summary'] as String).trim()
          : '제목 없음',
      memo: json['description'] as String?,
      location: json['location'] as String?,
      url: json['htmlLink'] as String?,
      startAt: start,
      endAt: end.isAfter(start)
          ? end
          : start.add(
              allDay ? const Duration(days: 1) : const Duration(hours: 1),
            ),
      allDay: allDay,
      recurrenceRule: recurrenceRule == null || recurrenceRule.isEmpty
          ? null
          : recurrenceRule,
      colorValue: calendar.colorValue,
      reminderMinutesBeforeList: _eventReminderMinutes(json, calendar),
    );
  }

  List<int> _eventReminderMinutes(
    Map<String, dynamic> json,
    ImportableCalendar calendar,
  ) {
    final reminders = json['reminders'];
    if (reminders is! Map<String, dynamic>) {
      return const [];
    }
    if (reminders['useDefault'] == true) {
      return calendar.defaultReminderMinutes;
    }
    return _googleReminderMinutes(reminders['overrides']);
  }

  List<int> _googleReminderMinutes(Object? value) {
    if (value is! List<Object?>) {
      return const [];
    }
    final minutes = <int>{};
    for (final item in value) {
      if (item is! Map<String, dynamic> || item['method'] != 'popup') {
        continue;
      }
      final minute = item['minutes'];
      if (minute is num && minute >= 0) {
        minutes.add(minute.toInt());
      }
    }
    final sorted = minutes.toList()..sort();
    return sorted;
  }

  DateTime? _googleDate(Map<String, dynamic> value, {required bool allDay}) {
    final raw = value[allDay ? 'date' : 'dateTime'] as String?;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return null;
    }
    return allDay
        ? DateTime(parsed.year, parsed.month, parsed.day)
        : parsed.toLocal();
  }

  bool _needsAdditionalAuthorization(http.Response response) =>
      response.statusCode == 401 || response.statusCode == 403;

  void _ensureSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CalendarImportException(
        'Google Calendar 데이터를 가져오지 못했습니다. (${response.statusCode})',
      );
    }
  }

  Map<String, dynamic> _jsonMap(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const CalendarImportException('Google Calendar 응답 형식이 올바르지 않습니다.');
    }
    return decoded;
  }

  int? _parseGoogleColor(String? value) {
    if (value == null || !value.startsWith('#')) {
      return null;
    }
    final rgb = int.tryParse(value.substring(1), radix: 16);
    return rgb == null ? null : 0xff000000 | rgb;
  }
}

class CalendarImportException implements Exception {
  const CalendarImportException(this.message);

  final String message;

  @override
  String toString() => message;
}
