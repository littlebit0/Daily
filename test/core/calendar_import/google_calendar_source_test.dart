import 'dart:convert';

import 'package:daily/core/calendar_import/calendar_import_models.dart';
import 'package:daily/core/calendar_import/google_calendar_source.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Google 캘린더 목록과 기본 계정 정보를 읽는다', () async {
    final auth = _FakeAuth();
    final source = GoogleCalendarSource(
      authService: auth,
      httpClient: MockClient((request) async {
        expect(request.url.path, '/calendar/v3/users/me/calendarList');
        expect(request.headers['authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'person@example.com',
                'summary': '내 캘린더',
                'primary': true,
                'backgroundColor': '#3367d6',
                'defaultReminders': [
                  {'method': 'popup', 'minutes': 30},
                  {'method': 'email', 'minutes': 60},
                ],
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final calendars = await source.listCalendars();

    expect(calendars, hasLength(1));
    expect(calendars.single.id, 'person@example.com');
    expect(calendars.single.accountName, 'person@example.com');
    expect(calendars.single.colorValue, 0xff3367d6);
    expect(calendars.single.defaultReminderMinutes, [30]);
    expect(
      auth.requestedScopes,
      contains(GoogleDriveAuthService.calendarReadonlyScope),
    );
  });

  test('특수 문자가 있는 캘린더 ID와 종일 일정을 안전하게 변환한다', () async {
    final auth = _FakeAuth();
    final source = GoogleCalendarSource(
      authService: auth,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/calendar/v3/calendars/person@example.com/events',
        );
        expect(request.url.toString(), isNot(contains('%2540')));
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'event-1',
                'summary': '휴가',
                'description': '메모',
                'location': '서울',
                'htmlLink': 'https://calendar.google.com/event?eid=1',
                'start': {'date': '2026-07-29'},
                'end': {'date': '2026-07-31'},
                'reminders': {
                  'useDefault': false,
                  'overrides': [
                    {'method': 'popup', 'minutes': 10},
                    {'method': 'email', 'minutes': 120},
                  ],
                },
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    const calendar = ImportableCalendar(
      id: 'person@example.com',
      title: '내 캘린더',
      provider: CalendarImportProvider.google,
    );

    final events = await source.loadEvents(const [calendar]);

    expect(events, hasLength(1));
    expect(events.single.title, '휴가');
    expect(events.single.allDay, isTrue);
    expect(events.single.startAt, DateTime(2026, 7, 29));
    expect(events.single.endAt, DateTime(2026, 7, 31));
    expect(events.single.memo, '메모');
    expect(events.single.location, '서울');
    expect(events.single.reminderMinutesBeforeList, [10]);
  });
}

class _FakeAuth extends GoogleDriveAuthService {
  _FakeAuth() : super(useDesktopOAuth: false);

  List<String> requestedScopes = const [];

  @override
  GoogleDriveAccount? get currentAccount =>
      const GoogleDriveAccount(email: 'person@example.com');

  @override
  Future<Map<String, String>?> authorizationHeadersForScopes(
    Iterable<String> requestedScopes, {
    bool promptIfNecessary = false,
  }) async {
    this.requestedScopes = requestedScopes.toList(growable: false);
    return const {'Authorization': 'Bearer test-token'};
  }
}
