abstract interface class BackupService {
  Future<String> backupNow();

  Future<void> restoreLatest();
}
