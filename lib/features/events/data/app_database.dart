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
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get category => text().withDefault(const Constant('other'))();
  IntColumn get colorValue => integer()();
  IntColumn get reminderMinutesBefore => integer().nullable()();
  TextColumn get recurrenceFrequency =>
      text().withDefault(const Constant('none'))();
  IntColumn get recurrenceInterval =>
      integer().withDefault(const Constant(1))();
  DateTimeColumn get recurrenceUntil => dateTime().nullable()();
  IntColumn get recurrenceCount => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deviceId => text().withDefault(const Constant(''))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [EventRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

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
