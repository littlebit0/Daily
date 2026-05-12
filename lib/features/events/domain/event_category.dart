enum EventCategory {
  health('건강', 0xff2f9e9b, ['병원', '치과', '약', '검진', '운동', '진료']),
  work('업무', 0xff4f7cff, ['회의', '미팅', '업무', '프로젝트', '마감', '출근']),
  appointment('약속', 0xffff8a3d, ['약속', '점심', '저녁', '카페', '식사', '만남']),
  family('가족', 0xffb45cff, ['가족', '엄마', '아빠', '부모님', '동생', '형', '누나']),
  personal('개인', 0xff5b7c99, ['개인', '정리', '휴식', '독서', '공부']),
  travel('이동/여행', 0xff2f80ed, ['여행', '비행기', '기차', '이동', '호텔', '공항']),
  deadline('결제/마감', 0xffd64545, ['결제', '납부', '마감', '청구', '월세', '카드']),
  other('기타', 0xff7a7f87, []);

  const EventCategory(this.label, this.colorValue, this.keywords);

  final String label;
  final int colorValue;
  final List<String> keywords;

  static EventCategory fromName(String? name) {
    if (name == null || name.isEmpty) {
      return EventCategory.other;
    }
    return EventCategory.values.firstWhere(
      (category) => category.name == name || category.label == name,
      orElse: () => EventCategory.other,
    );
  }

  static EventCategory classify(String input) {
    final normalized = input.toLowerCase();
    for (final category in EventCategory.values) {
      if (category == EventCategory.other) {
        continue;
      }
      if (category.keywords.any(normalized.contains)) {
        return category;
      }
    }
    return EventCategory.other;
  }
}
