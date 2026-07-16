import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Keeps the platform authentication API behind Daily's app-lock policy.
class BiometricAuthService {
  BiometricAuthService({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  Future<bool> isAvailable() async {
    if (kIsWeb) {
      return false;
    }
    try {
      if (!await _localAuthentication.canCheckBiometrics) {
        return false;
      }
      return (await _localAuthentication.getAvailableBiometrics()).isNotEmpty;
    } on Object {
      return false;
    }
  }

  Future<bool> authenticate() async {
    if (!await isAvailable()) {
      return false;
    }
    try {
      return await _localAuthentication.authenticate(
        localizedReason: 'Daily 잠금을 해제하려면 생체 인증이 필요합니다.',
        biometricOnly: defaultTargetPlatform != TargetPlatform.windows,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    } on Object {
      return false;
    }
  }
}
