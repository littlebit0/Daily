import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppLockPrivacyService {
  static const _channel = MethodChannel('daily/app_lock_privacy');

  Future<void> setEnabled(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('setEnabled', {'enabled': enabled});
    } on PlatformException {
      // App locking remains usable even when a platform privacy API is absent.
    }
  }
}
