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
      contains(
        '<key>CADisableMinimumFrameDurationOnPhone</key>\n\t<true/>',
      ),
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
}
