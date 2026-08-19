import 'package:flutter/material.dart';

/// DEEP TIDE v2 — 시안 `Deep Tide v2.dc.html` (Rev 03 · 국내 앱 문법).
///
/// 이전 판의 이중 베젤·헤어라인 테두리를 걷어냈다. 국내 앱이 공통으로 쓰는
/// 두 겹 구조 — **회색 배경 위에 흰 카드** — 로 바꾸고, 구획은 1px 보더가
/// 아니라 면 분할로 나눈다.
abstract final class AppColors {
  // ── 면 ────────────────────────────────────────────────────────
  /// 화면 배경
  static const bg = Color(0xFFF4F5F7);

  /// 카드 · 하단 바
  static const surface = Color(0xFFFFFFFF);

  /// 배경과 같은 톤으로 카드 위에 눌러 넣는 면 (비활성 칩, 미기록 칸)
  static const fill = Color(0xFFF4F5F7);

  /// 카드 안 구분선
  static const line = Color(0xFFF0F2F4);

  // ── 텍스트 ────────────────────────────────────────────────────
  /// 제목·수치
  static const ink = Color(0xFF111417);

  /// 소제목
  static const ink2 = Color(0xFF3D464B);

  /// 본문
  static const body = Color(0xFF4E585E);

  /// 보조 본문 · 칩 라벨
  static const sub = Color(0xFF5B6469);

  /// 리스트 라벨
  static const label = Color(0xFF6B747A);

  /// 캡션 · 단위
  static const muted = Color(0xFF9BA3A8);

  /// 비활성 탭
  static const faint = Color(0xFFB5BBBF);

  /// 화살표 · 미기록 라벨
  static const disabled = Color(0xFFC3C9CD);

  /// 흰 면 위 글자
  static const onAccent = Color(0xFFFFFFFF);

  // ── 브랜드 ────────────────────────────────────────────────────
  /// 주색. 시안 주석: "정해진 브랜드 컬러가 나오면 이 값만 바꾸면 된다".
  static const accent = Color(0xFF0B9E82);

  /// 주색 진한 끝 — 배지 텍스트
  static const accentDark = Color(0xFF0A8A72);

  /// 주색 옅은 배경
  static const accentSoft = Color(0xFFE9F7F3);

  /// 희귀 등급 골드
  static const gold = Color(0xFFE0A02C);

  /// 희귀 칸 배경
  static const goldSoft = Color(0xFFFBF6EC);

  /// 알림 점
  static const alert = Color(0xFFF0483E);

  // ── 아이콘 칩 (물때 · 일출) ───────────────────────────────────
  static const chipBlueBg = Color(0xFFEEF2FE);
  static const chipBlueFg = Color(0xFF3A62D8);
  static const chipAmberBg = Color(0xFFFFF3E4);
  static const chipAmberFg = Color(0xFFD5811A);

  // ── 사진 플레이스홀더 줄무늬 ──────────────────────────────────
  static const photoA = Color(0xFFEDEFF1);
  static const photoB = Color(0xFFE4E7EA);
  static const photoGoldA = Color(0xFFF7EFDD);
  static const photoGoldB = Color(0xFFF0E5CB);

  /// 미기록 칸의 어종 실루엣
  static const silhouette = Color(0xFFDCE0E3);
  static const silhouetteGold = Color(0xFFEBDCBF);

  /// 미기록 라벨 (희귀)
  static const lockedGoldText = Color(0xFFD3C6A6);

  /// 사진 위에 얹는 반투명 배지
  static const scrim = Color(0x9E111417);
}

/// 보더 대신 면으로 나누므로 그림자는 아주 얕게만 쓴다.
abstract final class AppShadows {
  /// 하단 탭 바 위쪽 실선 그림자
  static const topLine = <BoxShadow>[
    BoxShadow(color: Color(0x0F111417), blurRadius: 0, offset: Offset(0, -1)),
  ];

  /// 하단 고정 CTA 바
  static const bottomBar = <BoxShadow>[
    BoxShadow(color: Color(0x0F111417), blurRadius: 0, offset: Offset(0, -1)),
  ];
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
