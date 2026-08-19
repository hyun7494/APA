import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// 단일 서체 체계.
///
/// 시안은 `Pretendard` 한 벌로만 짰다. 영문 모노스페이스 라벨을 전부 걷어낸
/// 판이라 서체가 둘일 이유가 없다.
///
/// **Pretendard는 google_fonts에 없어서 `Gothic A1`으로 대체했다.**
/// 같은 계열(기하학적 한글 산세리프)이고 w100~w900을 모두 제공해서 시안이
/// 쓰는 750·800 굵기를 낼 수 있다. 실제 Pretendard를 쓰려면 폰트 파일을
/// `assets/fonts/`에 넣고 pubspec에 등록한 뒤 이 파일의 [_font]만 바꾸면 된다.
///
/// 숫자는 별도 서체 대신 [FontFeature.tabularFigures]로 자릿수를 맞춘다.
abstract final class AppText {
  // ── 제목 ──────────────────────────────────────────────────────
  /// 홈 지수 등급 — 화면에서 가장 큰 글자 (38)
  static TextStyle get ratingHuge => _f(38, FontWeight.w800, 1, -1.7);

  /// 도감 진행도 수치 (34)
  static TextStyle get numberHuge => _f(34, FontWeight.w800, 1, -1.5, tabular: true);

  /// 어종명 (26)
  static TextStyle get pageTitle => _f(26, FontWeight.w800, 1.25, -1.04);

  /// 지표 수치 (22)
  static TextStyle get numberLarge =>
      _f(22, FontWeight.w800, 1.2, -0.88, tabular: true);

  /// 화면 타이틀 — "도감", "기록 추가" (21)
  static TextStyle get screenTitle => _f(21, FontWeight.w800, 1.3, -0.74);

  /// 지역 선택 헤더 (19)
  static TextStyle get locationTitle => _f(19, FontWeight.w800, 1.3, -0.57);

  /// 카드 안 수치 (19)
  static TextStyle get numberMedium =>
      _f(19, FontWeight.w700, 1.2, -0.57, tabular: true);

  /// 앱바 타이틀 (17)
  static TextStyle get appBarTitle => _f(17, FontWeight.w700, 1.3, -0.43);

  /// 섹션 제목 — "내 도감", "내 기록" (16)
  static TextStyle get sectionTitle => _f(16, FontWeight.w700, 1.35, -0.32);

  /// 리스트 행의 값 (16)
  static TextStyle get rowValue => _f(16, FontWeight.w700, 1.35, -0.32);

  // ── 본문 ──────────────────────────────────────────────────────
  /// 카드 소제목 — "오늘의 낚시지수" (15)
  static TextStyle get cardLabel =>
      _f(15, FontWeight.w700, 1.35, -0.15, color: AppColors.ink2);

  /// 본문 (15)
  static TextStyle get body => _f(15, FontWeight.w400, 1.6, -0.15, color: AppColors.body);

  /// 리스트 행의 라벨 (15)
  static TextStyle get rowLabel =>
      _f(15, FontWeight.w600, 1.35, -0.15, color: AppColors.label);

  /// 도감 칸 이름 · 칩 라벨 (14)
  static TextStyle get tileName => _f(14, FontWeight.w700, 1.35, -0.28);

  /// 칩 (14)
  static TextStyle get chip => _f(14, FontWeight.w600, 1.2, -0.14, color: AppColors.sub);

  /// 보조 본문 (14)
  static TextStyle get bodySmall =>
      _f(14, FontWeight.w600, 1.5, -0.14, color: AppColors.label);

  /// 상세 표의 값 (14.5)
  static TextStyle get infoValue => _f(14.5, FontWeight.w700, 1.35, -0.29);

  /// 캡션 · 지표 라벨 (13)
  static TextStyle get caption =>
      _f(13, FontWeight.w600, 1.4, -0.13, color: AppColors.muted);

  /// 단위 (13)
  static TextStyle get unit =>
      _f(13, FontWeight.w600, 1.2, 0, color: AppColors.muted);

  /// 배지 (13)
  static TextStyle get badge => _f(13, FontWeight.w700, 1.2, -0.13);

  /// 작은 배지 · 사진 위 카운트 (11)
  static TextStyle get badgeSmall => _f(11, FontWeight.w700, 1.2, 0);

  /// 하단 탭 라벨 (11)
  static TextStyle get navLabel =>
      _f(11, FontWeight.w600, 1.2, 0, color: AppColors.faint);

  static TextStyle _f(
    double size,
    FontWeight weight,
    double height,
    double spacing, {
    Color color = AppColors.ink,
    bool tabular = false,
  }) => GoogleFonts.gothicA1(
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    color: color,
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  );
}
