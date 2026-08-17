import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supports the four requested locales', () {
    expect(AppLocalizations.supportedLocales, const [
      Locale('ko'),
      Locale('en'),
      Locale('ja'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ]);
  });

  test('maps language preferences to an explicit locale', () {
    expect(localeForLanguage(AppLanguage.system), isNull);
    expect(localeForLanguage(AppLanguage.korean), const Locale('ko'));
    expect(localeForLanguage(AppLanguage.english), const Locale('en'));
    expect(localeForLanguage(AppLanguage.japanese), const Locale('ja'));
    expect(
      localeForLanguage(AppLanguage.traditionalChinese),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );
  });

  test('translates core navigation labels and falls back safely', () {
    const english = AppLocalizations(Locale('en'));
    const japanese = AppLocalizations(Locale('ja'));
    const traditionalChinese = AppLocalizations(
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );

    expect(english.text('설정'), 'Settings');
    expect(japanese.text('설정'), '設定');
    expect(traditionalChinese.text('설정'), '設定');
    expect(english.text('반복 없음'), 'Does not repeat');
    expect(japanese.text('매주'), '毎週');
    expect(traditionalChinese.text('매월'), '每月');
    expect(
      english.text('{count}주마다', args: const {'count': 2}),
      'Every 2 week(s)',
    );
    expect(english.text('사용자 일정 제목'), '사용자 일정 제목');
  });

  test('keeps calendar view names separate from weekday names', () {
    const english = AppLocalizations(Locale('en'));
    const japanese = AppLocalizations(Locale('ja'));

    expect(english.compactCalendarViewName(CalendarViewMode.week), 'Week');
    expect(english.compactCalendarViewName(CalendarViewMode.month), 'Month');
    expect(english.compactCalendarViewName(CalendarViewMode.day), 'Day');
    expect(english.text('일'), 'Sun');
    expect(japanese.compactCalendarViewName(CalendarViewMode.day), '日');
  });

  test('translates account and sync details', () {
    const english = AppLocalizations(Locale('en'));
    const japanese = AppLocalizations(Locale('ja'));
    const traditionalChinese = AppLocalizations(
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );

    expect(english.text('백업'), 'Back Up');
    expect(japanese.text('동기화 완료'), '同期完了');
    expect(
      traditionalChinese.text(
        '{providers} 로그인 연결됨',
        args: const {'providers': 'Apple · Google'},
      ),
      '已連結 Apple · Google 登入',
    );
  });

  test('translates quick view summary counts', () {
    const english = AppLocalizations(Locale('en'));
    const japanese = AppLocalizations(Locale('ja'));
    const traditionalChinese = AppLocalizations(
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );

    expect(english.text('일정 {count}개', args: const {'count': 14}), '14 events');
    expect(
      japanese.text('D-day {count}개', args: const {'count': 2}),
      'D-day 2件',
    );
    expect(
      traditionalChinese.text('공휴일 {count}개', args: const {'count': 3}),
      '3 個國定假日',
    );
  });

  test('translates only unchanged built-in category names', () {
    const english = AppLocalizations(Locale('en'));
    const japanese = AppLocalizations(Locale('ja'));
    const traditionalChinese = AppLocalizations(
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );

    expect(english.categoryName(id: 'basic', label: '기본'), 'Default');
    expect(japanese.categoryName(id: 'holiday', label: '공휴일'), '祝日');
    expect(
      traditionalChinese.categoryName(id: 'holiday', label: '공휴일'),
      '國定假日',
    );
    expect(
      english.categoryName(id: 'basic', label: 'My category'),
      'My category',
    );
    expect(english.categoryName(id: 'custom_1', label: '개인'), '개인');
  });

  test('translates Korean public holiday titles including combined days', () {
    const english = AppLocalizations(Locale('en'));
    const japanese = AppLocalizations(Locale('ja'));
    const traditionalChinese = AppLocalizations(
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );

    expect(english.holidayTitle('광복절'), 'Liberation Day');
    expect(japanese.holidayTitle('설날 연휴'), '旧正月連休');
    expect(traditionalChinese.holidayTitle('추석'), '秋夕');
    expect(
      english.holidayTitle('어린이날 · 대체공휴일'),
      "Children's Day · Substitute Holiday",
    );
    expect(english.eventTitle('개인 일정', holiday: false), '개인 일정');
  });
}
