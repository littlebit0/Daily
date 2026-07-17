import 'package:url_launcher/url_launcher.dart';

typedef BugReportLauncher = Future<bool> Function(Uri uri);

class BugReportEnvironment {
  const BugReportEnvironment({
    required this.version,
    required this.buildNumber,
    required this.platform,
    required this.osVersion,
  });

  final String version;
  final String buildNumber;
  final String platform;
  final String osVersion;
}

class BugReportService {
  static final Uri _newIssueUri = Uri.https(
    'github.com',
    '/littlebit0/Daily/issues/new',
  );

  static Uri buildReportUri(BugReportEnvironment environment) {
    final build = environment.buildNumber.trim().isEmpty
        ? '확인할 수 없음'
        : environment.buildNumber.trim();
    final body =
        '''## 문제 설명


## 재현 방법
1.

## 예상 동작


## 실제 동작


## 환경
- Daily: ${environment.version} ($build)
- 플랫폼: ${environment.platform}
- OS: ${environment.osVersion}

> 일정, 계정 정보, 메모 등 개인정보는 첨부하지 마세요.
''';

    return _newIssueUri.replace(
      queryParameters: {'title': '[Bug] 문제를 간단히 적어 주세요', 'body': body},
    );
  }

  static Future<bool> open(
    BugReportEnvironment environment, {
    BugReportLauncher? launcher,
  }) {
    final uri = buildReportUri(environment);
    return (launcher ?? _launchExternally)(uri);
  }

  static Future<bool> _launchExternally(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
