import 'package:daily/features/events/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema 5 migration repairs a partially added alarm schema', () async {
    final executor = NativeDatabase.memory(
      setup: (database) {
        database.execute('''
          CREATE TABLE event_records (
            id TEXT NOT NULL PRIMARY KEY,
            alarm_enabled INTEGER NOT NULL DEFAULT 0
              CHECK (alarm_enabled IN (0, 1))
          )
        ''');
        database.userVersion = 4;
      },
    );
    final database = AppDatabase.forTesting(executor);
    addTearDown(database.close);

    final columns = await database
        .customSelect('PRAGMA table_info(event_records)')
        .get();
    final names = columns.map((row) => row.read<String>('name')).toSet();
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();

    expect(names, containsAll(['alarm_enabled', 'all_day_alarm_minutes']));
    expect(version.read<int>('user_version'), 5);
  });
}
