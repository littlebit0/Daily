import 'package:daily/core/security/biometric_auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Apple device credentials are allowed when explicitly requested',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final client = _FakeDeviceAuthenticationClient();
      final service = BiometricAuthService(client: client);

      final authenticated = await service.authenticate(
        localizedReason: 'Daily 앱 잠금 해제',
        allowDeviceCredentials: true,
      );

      expect(authenticated, isTrue);
      expect(client.lastBiometricOnly, isFalse);
    },
  );

  test('ordinary Apple biometric requests remain biometric only', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final client = _FakeDeviceAuthenticationClient();
    final service = BiometricAuthService(client: client);

    final authenticated = await service.authenticate();

    expect(authenticated, isTrue);
    expect(client.lastBiometricOnly, isTrue);
  });

  test(
    'macOS companion authentication uses the native Apple channel',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('daily/apple_authentication');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final service = BiometricAuthService();
      expect(await service.isBiometricsOrCompanionAvailable(), isTrue);
      expect(
        await service.authenticateWithBiometricsOrCompanion(
          localizedReason: 'Touch ID 또는 Apple Watch',
        ),
        isTrue,
      );
      expect(calls.map((call) => call.method), [
        'isBiometricsOrCompanionAvailable',
        'authenticateBiometricsOrCompanion',
      ]);
    },
  );
}

class _FakeDeviceAuthenticationClient implements DeviceAuthenticationClient {
  bool? lastBiometricOnly;

  @override
  Future<bool> get canCheckBiometrics async => true;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => [
    BiometricType.face,
  ];

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required bool biometricOnly,
    required bool persistAcrossBackgrounding,
  }) async {
    lastBiometricOnly = biometricOnly;
    return true;
  }
}
