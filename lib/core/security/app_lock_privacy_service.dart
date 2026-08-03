import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../settings/app_settings.dart';

class AppLockPrivacyService {
  static const _channel = MethodChannel('daily/app_lock_privacy');
  static var _authenticationDepth = 0;

  static bool get configurationAuthenticationInProgress =>
      _authenticationDepth > 0;

  Future<void> setEnabled(bool enabled, {AppLockMethod? method}) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('setEnabled', {
        'enabled': enabled,
        if (method != null) 'method': method.name,
      });
    } on PlatformException {
      // App locking remains usable even when a platform privacy API is absent.
    }
  }

  Future<T> duringConfigurationAuthentication<T>(
    Future<T> Function() operation,
  ) async {
    _authenticationDepth += 1;
    if (_authenticationDepth == 1) {
      await _setAuthenticationSuppressed(true);
    }
    try {
      return await operation();
    } finally {
      _authenticationDepth -= 1;
      if (_authenticationDepth == 0) {
        await _setAuthenticationSuppressed(false);
      }
    }
  }

  Future<void> _setAuthenticationSuppressed(bool suppressed) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('setAuthenticationSuppressed', {
        'suppressed': suppressed,
      });
    } on PlatformException {
      // The Flutter lock gate still ignores configuration authentication.
    } on MissingPluginException {
      // Older development builds may not yet expose the native overlay.
    }
  }
}
