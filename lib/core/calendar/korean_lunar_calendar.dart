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

  static const _maxSolarCacheEntries = 512;
  static final Map<int, KoreanLunarDate?> _solarCache = {};

  KoreanLunarDate? fromSolar(DateTime date) {
    final cacheKey = date.year * 10000 + date.month * 100 + date.day;
    if (_solarCache.containsKey(cacheKey)) {
      return _solarCache[cacheKey];
    }
    final supported = klc.setSolarDate(date.year, date.month, date.day);
    if (!supported) {
      return _cacheSolarDate(cacheKey, null);
    }
    final iso = klc.getLunarIsoFormat();
    final parts = iso.split(' ');
    final dateParts = parts.first.split('-');
    if (dateParts.length != 3) {
      return _cacheSolarDate(cacheKey, null);
    }
    return _cacheSolarDate(
      cacheKey,
      KoreanLunarDate(
        year: int.parse(dateParts[0]),
        month: int.parse(dateParts[1]),
        day: int.parse(dateParts[2]),
        isLeapMonth: parts.length > 1,
      ),
    );
  }

  KoreanLunarDate? _cacheSolarDate(int key, KoreanLunarDate? value) {
    if (_solarCache.length >= _maxSolarCacheEntries) {
      _solarCache.remove(_solarCache.keys.first);
    }
    _solarCache[key] = value;
    return value;
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
