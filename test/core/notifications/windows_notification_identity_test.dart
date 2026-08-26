import 'package:daily/core/notifications/local_notification_service.dart';
import 'package:daily/core/platform/windows_build_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the production Windows notification identity unchanged', () {
    final identity = windowsNotificationIdentityForBuild(isTestEdition: false);

    expect(identity.appName, 'DailyCalendar');
    expect(identity.appUserModelId, 'Personal.Daily.Calendar');
    expect(identity.guid, '4c124e1f-e041-4f68-aa1e-9ee8ec1a4fb7');
  });

  test('uses an isolated Windows notification identity in test editions', () {
    final identity = windowsNotificationIdentityForBuild(isTestEdition: true);

    expect(identity.appName, 'DailyCalendar Test');
    expect(identity.appUserModelId, 'Personal.Daily.Calendar.Test');
    expect(identity.guid, '0734c50a-0934-4e91-ad45-58f8d2ea41d5');
    expect(
      identity.appUserModelId,
      isNot(windowsProductionNotificationIdentity.appUserModelId),
    );
    expect(identity.guid, isNot(windowsProductionNotificationIdentity.guid));
  });

  test('Debug and Profile are test editions while Release is production', () {
    expect(
      isWindowsTestEditionForMode(isDebugMode: true, isProfileMode: false),
      isTrue,
    );
    expect(
      isWindowsTestEditionForMode(isDebugMode: false, isProfileMode: true),
      isTrue,
    );
    expect(
      isWindowsTestEditionForMode(isDebugMode: false, isProfileMode: false),
      isFalse,
    );
  });
}
