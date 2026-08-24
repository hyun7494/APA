import 'package:flutter/material.dart';

import 'app_palette.dart';

export 'app_palette.dart';

/// DEEP TIDE v2 — 시안 `Deep Tide v2.dc.html` (Rev 03 · 국내 앱 문법)와
/// 다크 판(Rev 04).
///
/// 이전 판의 이중 베젤·헤어라인 테두리를 걷어냈다. 국내 앱이 공통으로 쓰는
/// 두 겹 구조 — **회색 배경 위에 흰 카드** — 로 바꾸고, 구획은 1px 보더가
/// 아니라 면 분할로 나눈다. 다크에서는 같은 구조를 톤만 뒤집어 쓴다.
///
/// 여기 있는 건 전부 **현재 팔레트를 가리키는 이름**이다. 값 자체는
/// [AppPalette.light] / [AppPalette.dark] 에 있고, 어느 쪽이 꽂히는지는
/// `ThemeScope` 가 정한다 — 화면 코드는 예전처럼 `AppColors.ink` 라고만 쓰면 된다.
///
/// 이 때문에 `const` 가 아니다. 색을 `const` 자리(예: `const BoxDecoration`,
/// 상수 기본 인자)에 넣으면 컴파일이 막히니 그 자리만 풀어 쓸 것.
abstract final class AppColors {
  static AppPalette _palette = AppPalette.light;

  static AppPalette get palette => _palette;

  /// 팔레트를 갈아끼운다. 바뀌었으면 true — 호출한 쪽이 트리를 다시 그려야 한다.
  static bool use(AppPalette next) {
    if (identical(_palette, next)) return false;
    _palette = next;
    return true;
  }

  static bool get isDark => _palette.isDark;

  // ── 면 ────────────────────────────────────────────────────────
  /// 화면 배경
  static Color get bg => _palette.bg;

  /// 카드 · 하단 바
  static Color get surface => _palette.surface;

  /// 카드 위에 눌러 넣는 면 (비활성 칩, 미기록 칸)
  static Color get fill => _palette.fill;

  /// 카드 안 구분선
  static Color get line => _palette.line;

  // ── 텍스트 ────────────────────────────────────────────────────
  /// 제목·수치
  static Color get ink => _palette.ink;

  /// 소제목
  static Color get ink2 => _palette.ink2;

  /// 본문
  static Color get body => _palette.body;

  /// 보조 본문 · 칩 라벨
  static Color get sub => _palette.sub;

  /// 리스트 라벨
  static Color get label => _palette.label;

  /// 캡션 · 단위
  static Color get muted => _palette.muted;

  /// 비활성 탭
  static Color get faint => _palette.faint;

  /// 화살표 · 미기록 라벨
  static Color get disabled => _palette.disabled;

  /// 주색 면 위 글자
  static Color get onAccent => _palette.onAccent;

  /// 주 버튼·선택된 칩의 면, 선택된 탭 — 라이트는 잉크, 다크는 주색.
  /// 위에 얹는 글자는 [onAccent] 다.
  static Color get emphasis => _palette.emphasis;

  // ── 브랜드 ────────────────────────────────────────────────────
  /// 주색. 시안 주석: "정해진 브랜드 컬러가 나오면 이 값만 바꾸면 된다".
  static Color get accent => _palette.accent;

  /// 주색의 대비 끝 — 배지 텍스트 (라이트는 더 진하게, 다크는 더 밝게)
  static Color get accentDark => _palette.accentDark;

  /// 주색 옅은 배경
  static Color get accentSoft => _palette.accentSoft;

  /// 희귀 등급 골드
  static Color get gold => _palette.gold;

  /// 희귀 칸 배경
  static Color get goldSoft => _palette.goldSoft;

  /// 알림 점
  static Color get alert => _palette.alert;

  // ── 아이콘 칩 (물때 · 일출) ───────────────────────────────────
  static Color get chipBlueBg => _palette.chipBlueBg;
  static Color get chipBlueFg => _palette.chipBlueFg;
  static Color get chipAmberBg => _palette.chipAmberBg;
  static Color get chipAmberFg => _palette.chipAmberFg;

  // ── 사진 플레이스홀더 줄무늬 ──────────────────────────────────
  static Color get photoA => _palette.photoA;
  static Color get photoB => _palette.photoB;
  static Color get photoGoldA => _palette.photoGoldA;
  static Color get photoGoldB => _palette.photoGoldB;

  /// 미기록 칸의 어종 실루엣
  static Color get silhouette => _palette.silhouette;
  static Color get silhouetteGold => _palette.silhouetteGold;

  /// 미기록 라벨 (희귀)
  static Color get lockedGoldText => _palette.lockedGoldText;

  /// 사진 위에 얹는 반투명 배지
  static Color get scrim => _palette.scrim;
}

/// 보더 대신 면으로 나누므로 그림자는 아주 얕게만 쓴다.
abstract final class AppShadows {
  /// 하단 탭 바 위쪽 실선 그림자
  static List<BoxShadow> get topLine => [
    BoxShadow(
      color: AppColors.palette.hairline,
      blurRadius: 0,
      offset: const Offset(0, -1),
    ),
  ];

  /// 하단 고정 CTA 바
  static List<BoxShadow> get bottomBar => topLine;
}

abstract final class AppRadius {
  /// 큰 카드 (홈 지수, 내 도감)
  static const card = 24.0;

  /// 중간 카드 (물때 타일, 어종 상세 지표)
  static const cardSmall = 20.0;

  /// 작은 카드 · 리스트 카드
  static const cardTight = 18.0;

  /// 도감 칸 · 사진 타일
  static const tile = 16.0;

  /// 썸네일
  static const thumb = 14.0;

  /// 아이콘 칩
  static const iconChip = 11.0;

  /// 필터 칩 · 사각 버튼 — 시안은 알약이 아니라 라운드 사각이다
  static const chip = 10.0;

  /// 완전 둥근 배지
  static const pill = 999.0;
}

abstract final class AppSpacing {
  /// 화면 좌우 여백
  static const screen = 20.0;

  /// 카드 사이
  static const gap = 10.0;

  /// 섹션 사이
  static const section = 22.0;

  /// 하단 탭 바에 가리지 않도록 스크롤 끝에 주는 여백
  static const navClearance = 108.0;

  /// 하단 고정 CTA 바가 있는 화면의 스크롤 끝 여백
  static const ctaClearance = 112.0;
}
