import 'package:daily/core/maps/map_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('daily/map_launcher');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sends a trimmed location to the native map launcher', () async {
    MethodCall? call;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          call = methodCall;
          return 'handled';
        });

    await MapLauncher(channel: channel).openLocation('  서울특별시 중구 세종대로 110  ');

    expect(call?.method, 'openLocation');
    expect(call?.arguments, {'location': '서울특별시 중구 세종대로 110'});
  });

  test('does not call the native launcher for a blank location', () async {
    var called = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          called = true;
          return 'handled';
        });

    await MapLauncher(channel: channel).openLocation('   ');

    expect(called, isFalse);
  });
}
