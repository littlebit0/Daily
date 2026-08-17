import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/features/settings/presentation/siri_activity_log_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('daily/siri_logs');

  setUpAll(() => initializeDateFormatting('en'));

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('shows Siri activity grouped by execution date', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'listLogs') return null;
          return <Object?>[
            <String, Object?>{
              'occurredAt': DateTime(2026, 8, 13, 9, 30).millisecondsSinceEpoch,
              'action': 'add',
              'summary': '회의',
              'result': 'completed',
              'success': true,
              'details': <String, String>{
                'title': '회의',
                'startAtMillis': DateTime(
                  2026,
                  8,
                  13,
                  9,
                ).millisecondsSinceEpoch.toString(),
                'endAtMillis': DateTime(
                  2026,
                  8,
                  13,
                  11,
                ).millisecondsSinceEpoch.toString(),
                'allDay': 'false',
                'location': '회의실',
                'memo': '자료 준비',
              },
            },
            <String, Object?>{
              'occurredAt': DateTime(2026, 8, 12, 18).millisecondsSinceEpoch,
              'action': 'search',
              'summary': '병원',
              'result': 'databaseUnavailable',
              'success': false,
            },
          ];
        });

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('회의'), findsOneWidget);
    expect(find.text('병원'), findsOneWidget);
    expect(find.textContaining('Success'), findsOneWidget);
    expect(find.textContaining('Failed'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    await tester.tap(find.text('회의'));
    await tester.pumpAndSettle();

    expect(find.text('Siri Action Details'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('회의실'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('자료 준비'), findsOneWidget);
  });

  testWidgets('clears all Siri activity after confirmation', (tester) async {
    var cleared = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'listLogs') {
            return <Object?>[
              <String, Object?>{
                'occurredAt': DateTime(2026, 8, 13).millisecondsSinceEpoch,
                'action': 'open',
                'summary': 'Daily calendar',
                'result': 'completed',
                'success': true,
              },
            ];
          }
          if (call.method == 'clearLogs') cleared = true;
          return null;
        });

    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear all activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(cleared, isTrue);
    expect(find.text('No Siri activity recorded.'), findsOneWidget);
  });
}

Widget _testApp() {
  return const MaterialApp(
    locale: Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [AppLocalizations.delegate],
    home: SiriActivityLogPage(),
  );
}
