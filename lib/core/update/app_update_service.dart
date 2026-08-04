import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateService {
  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  static final _latestReleaseUri = Uri.parse(
    'https://api.github.com/repos/littlebit0/Daily/releases/latest',
  );

  final http.Client _client;

  Future<void> checkAndInstallIfAvailable() async {
    if (!Platform.isWindows) {
      return;
    }
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final response = await _client.get(
        _latestReleaseUri,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'Daily-Windows-Updater',
        },
      );
      if (response.statusCode != HttpStatus.ok) {
        return;
      }
      final release = jsonDecode(response.body) as Map<String, dynamic>;
      final version = (release['tag_name'] as String? ?? '').replaceFirst(
        RegExp(r'^v'),
        '',
      );
      if (!isNewerVersion(version, packageInfo.version)) {
        return;
      }
      final assetName = 'daily-windows-$version-setup.exe';
      final assets = (release['assets'] as List<dynamic>? ?? const []);
      final asset = assets.cast<Map<String, dynamic>>().where(
        (item) => item['name'] == assetName,
      );
      if (asset.isEmpty) {
        return;
      }
      final downloadUrl = asset.first['browser_download_url'] as String?;
      if (downloadUrl == null || downloadUrl.isEmpty) {
        return;
      }
      final directory = await Directory.systemTemp.createTemp('daily-update-');
      final installer = File('${directory.path}\\$assetName');
      final download = await _client.get(Uri.parse(downloadUrl));
      if (download.statusCode != HttpStatus.ok || download.bodyBytes.isEmpty) {
        return;
      }
      await installer.writeAsBytes(download.bodyBytes, flush: true);
      await Process.start('cmd.exe', [
        '/c',
        'timeout /t 2 /nobreak >nul & start "" /wait "${installer.path}" '
            '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS',
      ], mode: ProcessStartMode.detached);
      exit(0);
    } on Object {
      // Update checks must never prevent the calendar from starting.
    }
  }
}

bool isNewerVersion(String candidate, String current) {
  final candidateParts = _versionParts(candidate);
  final currentParts = _versionParts(current);
  for (var index = 0; index < 3; index++) {
    if (candidateParts[index] != currentParts[index]) {
      return candidateParts[index] > currentParts[index];
    }
  }
  return false;
}

List<int> _versionParts(String version) {
  final match = RegExp(r'^(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(version);
  if (match == null) {
    return const [0, 0, 0];
  }
  return [
    int.parse(match.group(1)!),
    int.tryParse(match.group(2) ?? '') ?? 0,
    int.tryParse(match.group(3) ?? '') ?? 0,
  ];
}
