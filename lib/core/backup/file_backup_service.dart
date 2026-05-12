import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/events/data/app_database.dart';
import 'backup_service.dart';

class FileBackupService implements BackupService {
  FileBackupService(this._database);

  final AppDatabase _database;

  @override
  Future<String> backupNow() async {
    final databaseFile = await _database.databaseFile();
    final documents = await getApplicationDocumentsDirectory();
    final backupDirectory = Directory(p.join(documents.path, 'Daily Backups'));
    await backupDirectory.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupFile = File(
      p.join(backupDirectory.path, 'daily-$stamp.sqlite'),
    );
    await databaseFile.copy(backupFile.path);
    return backupFile.path;
  }

  @override
  Future<void> restoreLatest() async {
    final databaseFile = await _database.databaseFile();
    final documents = await getApplicationDocumentsDirectory();
    final backupDirectory = Directory(p.join(documents.path, 'Daily Backups'));
    if (!await backupDirectory.exists()) {
      throw StateError('복원할 백업 파일이 없습니다.');
    }

    final backups =
        backupDirectory
            .listSync()
            .whereType<File>()
            .where((file) => p.extension(file.path) == '.sqlite')
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));

    if (backups.isEmpty) {
      throw StateError('복원할 백업 파일이 없습니다.');
    }

    final safetyStamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    await databaseFile.copy(
      p.join(backupDirectory.path, 'daily-before-restore-$safetyStamp.sqlite'),
    );
    await backups.first.copy(databaseFile.path);
  }
}
