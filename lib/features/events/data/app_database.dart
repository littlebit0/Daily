import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class EventRecords extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get memo => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get url => text().nullable()();
  TextColumn get weather => text().nullable()();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get category => text().withDefault(const Constant('basic'))();
  IntColumn get colorValue => integer()();
  IntColumn get reminderMinutesBefore => integer().nullable()();
  TextColumn get recurrenceFrequency =>
      text().withDefault(const Constant('none'))();
  IntColumn get recurrenceInterval =>
      integer().withDefault(const Constant(1))();
  DateTimeColumn get recurrenceUntil => dateTime().nullable()();
  IntColumn get recurrenceCount => integer().nullable()();
  TextColumn get recurrenceExcludedDates =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deviceId => text().withDefault(const Constant(''))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  BoolColumn get showDday => boolean().withDefault(const Constant(false))();
  BoolColumn get sensitive => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [EventRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await migrator.addColumn(eventRecords, eventRecords.showDday);
          await customStatement(
            "UPDATE event_records SET category = 'basic', color_value = 4280640491 WHERE category != 'holiday'",
          );
        }
        if (from < 3) {
          await migrator.addColumn(eventRecords, eventRecords.url);
          await migrator.addColumn(eventRecords, eventRecords.weather);
          await migrator.addColumn(eventRecords, eventRecords.sensitive);
          await migrator.addColumn(
            eventRecords,
            eventRecords.recurrenceExcludedDates,
          );
        }
      },
    );
  }

  Future<File> databaseFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, 'daily.sqlite'));
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, 'daily.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
