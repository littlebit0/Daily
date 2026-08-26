import 'package:daily/core/update/app_update_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects newer semantic versions', () {
    expect(isNewerVersion('3.0.2', '3.0.1'), isTrue);
    expect(isNewerVersion('3.1.0', '3.0.9'), isTrue);
    expect(isNewerVersion('4.0.0', '3.9.9'), isTrue);
  });

  test('does not update for equal, older, or invalid versions', () {
    expect(isNewerVersion('3.0.1', '3.0.1'), isFalse);
    expect(isNewerVersion('3.0.0', '3.0.1'), isFalse);
    expect(isNewerVersion('invalid', '3.0.1'), isFalse);
  });

  test('runs the Windows auto updater only in release mode', () {
    expect(
      shouldRunWindowsAutoUpdater(
        targetPlatform: TargetPlatform.windows,
        isReleaseMode: true,
      ),
      isTrue,
    );
    expect(
      shouldRunWindowsAutoUpdater(
        targetPlatform: TargetPlatform.windows,
        isReleaseMode: false,
      ),
      isFalse,
    );
    expect(
      shouldRunWindowsAutoUpdater(
        targetPlatform: TargetPlatform.macOS,
        isReleaseMode: true,
      ),
      isFalse,
    );
  });
}
