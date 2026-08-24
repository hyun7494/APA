import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 낚시 지수 등급 4단계.
///
/// 서버 `fishing_spots.rating` 값(VERY_GOOD | GOOD | NORMAL | BAD)과 1:1 대응.
///
/// 시안 v2: 배지는 색면 + 글자만 쓰고 앞의 점 표시를 뺐다. 등급 구분은
/// 색으로 충분하고, 점은 배지 폭만 늘린다.
///
/// 등급 색은 [AppColors] 팔레트에 없다 — 등급마다 고유한 색이라 토큰으로
/// 나누면 이름만 늘어난다. 대신 밝은 판/어두운 판을 여기 나란히 두고
/// [background] · [foreground] 가 현재 팔레트에 맞는 쪽을 고른다.
enum Rating {
  veryGood(
    code: 'VERY_GOOD',
    label: '아주 좋음',
    level: 4,
    lightBackground: Color(0xFFE9F7F3),
    lightForeground: Color(0xFF0A8A72),
    darkBackground: Color(0xFF1A3834),
    darkForeground: Color(0xFF10B981),
  ),
  good(
    code: 'GOOD',
    label: '좋음',
    level: 3,
    lightBackground: Color(0xFFEEF2FE),
    lightForeground: Color(0xFF2D55C8),
    darkBackground: Color(0xFF213045),
    darkForeground: Color(0xFF60A5FA),
  ),
  normal(
    code: 'NORMAL',
    label: '보통',
    level: 2,
    lightBackground: Color(0xFFFFF3E4),
    lightForeground: Color(0xFFB57612),
    darkBackground: Color(0xFF3D3422),
    darkForeground: Color(0xFFFBBF24),
  ),
  bad(
    code: 'BAD',
    label: '나쁨',
    level: 1,
    lightBackground: Color(0xFFFDEDEA),
    lightForeground: Color(0xFFC7382A),
    darkBackground: Color(0xFF3C262B),
    darkForeground: Color(0xFFF87171),
  );

  const Rating({
    required this.code,
    required this.label,
    required this.level,
    required this.lightBackground,
    required this.lightForeground,
    required this.darkBackground,
    required this.darkForeground,
  });

  final String code;
  final String label;

  /// 1(나쁨) ~ 4(아주 좋음)
  final int level;

  final Color lightBackground;
  final Color lightForeground;
  final Color darkBackground;
  final Color darkForeground;

  /// 배지 배경 — 현재 팔레트에 맞는 판을 고른다.
  Color get background => AppColors.isDark ? darkBackground : lightBackground;

  /// 배지 텍스트 · 홈 지수 큰 글자
  Color get foreground => AppColors.isDark ? darkForeground : lightForeground;

  /// "4.0" — 시안은 링 게이지 대신 4점 만점 표기를 쓴다.
  String get score => level.toDouble().toStringAsFixed(1);

  static Rating fromCode(String? code) => Rating.values.firstWhere(
    (r) => r.code == code,
    orElse: () => Rating.normal,
  );
}
