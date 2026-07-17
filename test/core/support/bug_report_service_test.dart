import 'package:daily/core/support/bug_report_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const environment = BugReportEnvironment(
    version: '2.7.0',
    buildNumber: '3',
    platform: 'iOS',
    osVersion: 'iOS 26.5.2',
  );

  test('builds a prefilled GitHub issue without app user data', () {
    final uri = BugReportService.buildReportUri(environment);

    expect(uri.scheme, 'https');
    expect(uri.host, 'github.com');
    expect(uri.path, '/littlebit0/Daily/issues/new');
    expect(uri.queryParameters['title'], startsWith('[Bug]'));

    final body = uri.queryParameters['body']!;
    expect(body, contains('## 문제 설명'));
    expect(body, contains('## 재현 방법'));
    expect(body, contains('## 예상 동작'));
    expect(body, contains('## 실제 동작'));
    expect(body, contains('Daily: 2.7.0 (3)'));
    expect(body, contains('플랫폼: iOS'));
    expect(body, contains('OS: iOS 26.5.2'));
    expect(body, contains('개인정보는 첨부하지 마세요'));
    expect(body, isNot(contains('일정 제목')));
    expect(body, isNot(contains('사용자 이메일')));
  });

  test('opens the generated issue in the supplied launcher', () async {
    Uri? launchedUri;

    final opened = await BugReportService.open(
      environment,
      launcher: (uri) async {
        launchedUri = uri;
        return true;
      },
    );

    expect(opened, isTrue);
    expect(launchedUri, BugReportService.buildReportUri(environment));
  });
}
