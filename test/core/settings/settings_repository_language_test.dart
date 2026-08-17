import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to system language and persists an override', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);

    expect(repository.load().language, AppLanguage.system);

    await repository.save(
      repository.load().copyWith(language: AppLanguage.japanese),
      markSyncPending: false,
    );

    expect(repository.load().language, AppLanguage.japanese);
  });
}
