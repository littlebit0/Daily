import 'package:klc/klc.dart' as klc;

class KoreanLunarDate {
  const KoreanLunarDate({
    required this.year,
    required this.month,
    required this.day,
    required this.isLeapMonth,
  });

  final int year;
  final int month;
  final int day;
  final bool isLeapMonth;

  String get shortLabel {
    final prefix = isLeapMonth ? '윤' : '';
    return '$prefix$month.$day';
  }
}

class KoreanLunarCalendar {
  const KoreanLunarCalendar();

  KoreanLunarDate? fromSolar(DateTime date) {
    final supported = klc.setSolarDate(date.year, date.month, date.day);
    if (!supported) {
      return null;
    }
    final iso = klc.getLunarIsoFormat();
    final parts = iso.split(' ');
    final dateParts = parts.first.split('-');
    if (dateParts.length != 3) {
      return null;
    }
    return KoreanLunarDate(
      year: int.parse(dateParts[0]),
      month: int.parse(dateParts[1]),
      day: int.parse(dateParts[2]),
      isLeapMonth: parts.length > 1,
    );
  }

  DateTime? toSolar({
    required int year,
    required int month,
    required int day,
    bool isLeapMonth = false,
  }) {
    final supported = klc.setLunarDate(year, month, day, isLeapMonth);
    if (!supported) {
      return null;
    }
    final parts = klc.getSolarIsoFormat().split('-');
    if (parts.length != 3) {
      return null;
    }
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
