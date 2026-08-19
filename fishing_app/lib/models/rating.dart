import 'package:flutter/material.dart';

/// 낚시 지수 등급 4단계.
///
/// 서버 `fishing_spots.rating` 값(VERY_GOOD | GOOD | NORMAL | BAD)과 1:1 대응.
///
/// 시안 v2: 배지는 색면 + 글자만 쓰고 앞의 점 표시를 뺐다. 등급 구분은
/// 색으로 충분하고, 점은 배지 폭만 늘린다.
enum Rating {
  veryGood(
    code: 'VERY_GOOD',
    label: '아주 좋음',
    level: 4,
    background: Color(0xFFE9F7F3),
    foreground: Color(0xFF0A8A72),
  ),
  good(
    code: 'GOOD',
    label: '좋음',
    level: 3,
    background: Color(0xFFEEF2FE),
    foreground: Color(0xFF2D55C8),
  ),
  normal(
    code: 'NORMAL',
    label: '보통',
    level: 2,
    background: Color(0xFFFFF3E4),
    foreground: Color(0xFFB57612),
  ),
  bad(
    code: 'BAD',
    label: '나쁨',
    level: 1,
    background: Color(0xFFFDEDEA),
    foreground: Color(0xFFC7382A),
  );

  const Rating({
    required this.code,
    required this.label,
    required this.level,
    required this.background,
    required this.foreground,
  });

  final String code;
  final String label;

  /// 1(나쁨) ~ 4(아주 좋음)
  final int level;

  /// 배지 배경
  final Color background;

  /// 배지 텍스트 · 홈 지수 큰 글자
  final Color foreground;

  /// "4.0" — 시안은 링 게이지 대신 4점 만점 표기를 쓴다.
  String get score => level.toDouble().toStringAsFixed(1);

  static Rating fromCode(String? code) => Rating.values.firstWhere(
    (r) => r.code == code,
    orElse: () => Rating.normal,
  );
}
