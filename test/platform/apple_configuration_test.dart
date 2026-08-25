import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS declares why Daily uses Face ID', () async {
    final plist = await File('ios/Runner/Info.plist').readAsString();

    expect(plist, contains('<key>NSFaceIDUsageDescription</key>'));
    expect(plist, contains('Daily 앱 잠금을 안전하게 해제하기 위해 Face ID를 사용합니다.'));
  });

  test('iOS unlocks the full dynamic ProMotion refresh-rate range', () async {
    final plist = await File('ios/Runner/Info.plist').readAsString();

    expect(
      plist,
      contains('<key>CADisableMinimumFrameDurationOnPhone</key>\n\t<true/>'),
    );
  });

  test('Apple runners do not force a fixed application frame rate', () async {
    final sources = await Future.wait([
      File('ios/Runner/AppDelegate.swift').readAsString(),
      File('macos/Runner/AppDelegate.swift').readAsString(),
    ]);
    final runnerSource = sources.join('\n');

    expect(runnerSource, isNot(contains('preferredFramesPerSecond')));
    expect(runnerSource, isNot(contains('preferredFrameRateRange')));
  });

  test(
    'Apple widgets follow Daily theme settings and expose checkbox Todo actions',
    () async {
      final source = await File(
        'apple_widgets/DailyWidgets.swift',
      ).readAsString();

      expect(source, contains('@Environment(\\.colorScheme)'));
      expect(source, contains('switch themeMode'));
      expect(source, contains('case "light":'));
      expect(source, contains('case "dark":'));
      expect(source, contains('return systemColorScheme'));
      expect(source, contains('resolvedColorScheme'));
      expect(source, contains('.environment(\\.colorScheme, colorScheme)'));
      expect(source, contains('themeIdentity'));
      expect(source, isNot(contains('.background(background)')));
      expect(source, contains('WidgetCenter.shared.reloadAllTimelines()'));
      expect(source, isNot(contains('reloadTimelines(ofKind:')));
      expect(source, contains('static let today = "DailyTodayWidget"'));
      expect(source, contains('static let calendar = "DailyMonthWidget"'));
      expect(source, contains('static let dday = "DailyDdayWidget"'));
      expect(source, contains('static let dailyText = Color.primary'));
      expect(
        source,
        contains(
          'modifier(DailyWidgetBackgroundModifier(themeMode: themeMode))',
        ),
      );
      expect(
        '.dailyWidgetBackground(themeMode: entry.snapshot.themeMode)'
            .allMatches(source)
            .length,
        4,
      );
      expect(
        source,
        isNot(contains('Color(red: 0.98, green: 0.985, blue: 1.0)')),
      );
      expect(source, contains('private struct DailyTodoToggle: View'));
      expect(source, contains('struct DailyToggleTodoIntent: AppIntent'));
      expect(
        source,
        isNot(contains('private struct DailyToggleTodoIntent: AppIntent')),
      );
      expect(
        source,
        contains('Button(\n        intent: DailyToggleTodoIntent'),
      );
      expect(source, contains('DailyTodoToggle(event: event)'));
      expect(source, contains('.dailyTodoCompletion(event.completed == true)'));
      expect(source, contains('snapshot["generatedAt"]'));
      expect(source, contains('notifyApp()'));
    },
  );

  test('Daily coalesces rapid Apple widget theme refreshes', () async {
    final sources = await Future.wait([
      File('lib/core/widgets/apple_widget_service.dart').readAsString(),
      File('lib/app/daily_app.dart').readAsString(),
    ]);
    final serviceSource = sources[0];
    final appSource = sources[1];

    expect(
      serviceSource,
      contains(
        'Duration themeRefreshDelay = const Duration(milliseconds: 400)',
      ),
    );
    expect(
      serviceSource,
      contains('final generation = ++_themeRefreshGeneration'),
    );
    expect(serviceSource, contains('generation != _themeRefreshGeneration'));
    expect(appSource, contains('previous?.themeMode != next.themeMode'));
    expect(appSource, contains('.refreshTheme().catchError'));
  });

  test('Apple runners receive live widget Todo action signals', () async {
    final sources = await Future.wait([
      File('ios/Runner/AppDelegate.swift').readAsString(),
      File('macos/Runner/MainFlutterWindow.swift').readAsString(),
    ]);

    for (final source in sources) {
      expect(source, contains('todoActionsChanged'));
      expect(source, contains('widgetTodoActionsChanged'));
      expect(source, contains('WidgetCenter.shared.reloadAllTimelines()'));
      expect(source, isNot(contains('reloadTimelines(ofKind:')));
    }
  });

  test(
    'Signal is shipped as an automatically discoverable App Shortcut',
    () async {
      final source = await File(
        'apple_siri/DailySiriIntents.swift',
      ).readAsString();

      expect(source, contains('intent: DailySignalCommandIntent()'));
      expect(source, contains('"\\(.applicationName)에서 시그널 실행"'));
      expect(source, contains('shortTitle: "Signal"'));
    },
  );
}
