import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/core/siri/signal_voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('daily/signal_voice');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('runs recognized text through the native Signal bridge', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'startListening' => '내일 일정 알려줘',
            'runSignal' => <String, Object?>{
              'message': '내일 일정이 없습니다.',
              'success': true,
            },
            'speak' => null,
            _ => throw PlatformException(code: 'unexpected_method'),
          };
        });

    final service = SignalVoiceService.instance;
    final transcript = await service.startListening();
    final result = await service.runSignal(transcript);
    await service.speak(result.message);

    expect(transcript, '내일 일정 알려줘');
    expect(result.success, isTrue);
    expect(result.message, '내일 일정이 없습니다.');
    expect(calls.map((call) => call.method), [
      'startListening',
      'runSignal',
      'speak',
    ]);
    expect(calls[1].arguments, {'command': '내일 일정 알려줘', 'confirmed': false});
  });

  test('separates finishing an utterance from cancelling it', () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          return null;
        });

    final service = SignalVoiceService.instance;
    await service.finishListening();
    await service.cancelListening();

    expect(methods, ['finishListening', 'cancelListening']);
  });
}
