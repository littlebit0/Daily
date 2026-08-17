import 'package:flutter/services.dart';

class SignalVoiceResult {
  const SignalVoiceResult({required this.message, required this.success});

  final String message;
  final bool success;
}

class SignalVoiceService {
  SignalVoiceService._();

  static final SignalVoiceService instance = SignalVoiceService._();
  static const MethodChannel _channel = MethodChannel('daily/signal_voice');

  void Function(String transcript)? _onTranscriptChanged;
  void Function()? _onListeningStarted;

  void setHandlers({
    void Function(String transcript)? onTranscriptChanged,
    void Function()? onListeningStarted,
  }) {
    _onTranscriptChanged = onTranscriptChanged;
    _onListeningStarted = onListeningStarted;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'transcriptChanged') {
        _onTranscriptChanged?.call(call.arguments as String? ?? '');
      } else if (call.method == 'listeningStarted') {
        _onListeningStarted?.call();
      }
    });
  }

  Future<String> startListening() async {
    return (await _channel.invokeMethod<String>('startListening')) ?? '';
  }

  Future<void> finishListening() =>
      _channel.invokeMethod<void>('finishListening');

  Future<void> cancelListening() =>
      _channel.invokeMethod<void>('cancelListening');

  Future<SignalVoiceResult> runSignal(
    String command, {
    bool confirmed = false,
  }) async {
    final response = await _channel.invokeMapMethod<String, Object?>(
      'runSignal',
      {'command': command, 'confirmed': confirmed},
    );
    return SignalVoiceResult(
      message: response?['message'] as String? ?? '',
      success: response?['success'] as bool? ?? false,
    );
  }

  Future<void> speak(String message) =>
      _channel.invokeMethod<void>('speak', {'message': message});
}
