class KoreaTime {
  const KoreaTime();

  static const timeZoneName = 'Asia/Seoul';

  DateTime now() => DateTime.now().toUtc().add(const Duration(hours: 9));

  DateTime date(int year, int month, int day) {
    return DateTime(year, month, day);
  }

  DateTime monthStart(DateTime value) {
    return DateTime(value.year, value.month);
  }

  DateTime dayStart(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
