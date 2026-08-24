import 'package:flutter/material.dart';

/// 한 벌의 색 팔레트.
///
/// 토큰 이름은 라이트/다크가 똑같다. 화면 코드는 [AppColors] 를 통해 이름으로만
/// 색을 부르고, 어느 벌이 꽂혀 있는지는 알 필요가 없다.
///
/// 다크 값은 시안 `Deep Tide v2 · 다크모드 적용`(Rev 04)과 `DESIGN.md` 의
/// 톤 레이어 규칙을 따른다 — 배경 #111417(L0) 위에 카드 #1C2126(L1),
/// 그 위에 눌러 넣는 면·구분선 #2D333B(L2).
@immutable
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.fill,
    required this.line,
    required this.ink,
    required this.ink2,
    required this.body,
    required this.sub,
    required this.label,
    required this.muted,
    required this.faint,
    required this.disabled,
    required this.onAccent,
    required this.emphasis,
    required this.accent,
    required this.accentDark,
    required this.accentSoft,
    required this.gold,
    required this.goldSoft,
    required this.alert,
    required this.chipBlueBg,
    required this.chipBlueFg,
    required this.chipAmberBg,
    required this.chipAmberFg,
    required this.photoA,
    required this.photoB,
    required this.photoGoldA,
    required this.photoGoldB,
    required this.silhouette,
    required this.silhouetteGold,
    required this.lockedGoldText,
    required this.scrim,
    required this.hairline,
  });

  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  // ── 면 ────────────────────────────────────────────────────────
  final Color bg;
  final Color surface;
  final Color fill;
  final Color line;

  // ── 텍스트 ────────────────────────────────────────────────────
  final Color ink;
  final Color ink2;
  final Color body;
  final Color sub;
  final Color label;
  final Color muted;
  final Color faint;
  final Color disabled;
  final Color onAccent;

  /// 가장 세게 강조하는 색 — 주 버튼·선택된 칩의 면, 선택된 탭의 아이콘.
  ///
  /// 라이트에서는 잉크(거의 검정)지만 다크에서는 **잉크가 흰색**이라 그대로
  /// 쓰면 흰 버튼에 흰 글자가 된다. 시안 다크 판도 이 자리를 전부 주색으로
  /// 채운다 — 그래서 별도 토큰이다.
  final Color emphasis;

  // ── 브랜드 ────────────────────────────────────────────────────
  final Color accent;
  final Color accentDark;
  final Color accentSoft;
  final Color gold;
  final Color goldSoft;
  final Color alert;

  // ── 아이콘 칩 ─────────────────────────────────────────────────
  final Color chipBlueBg;
  final Color chipBlueFg;
  final Color chipAmberBg;
  final Color chipAmberFg;

  // ── 사진 플레이스홀더 ─────────────────────────────────────────
  final Color photoA;
  final Color photoB;
  final Color photoGoldA;
  final Color photoGoldB;
  final Color silhouette;
  final Color silhouetteGold;
  final Color lockedGoldText;
  final Color scrim;

  /// 하단 탭 바·CTA 바 위에 얹는 1px 선. 라이트는 검정 6%, 다크는 흰색 5% —
  /// 다크에서 검정 선은 배경에 묻혀 아예 보이지 않는다.
  final Color hairline;

  /// 회색 배경 위에 흰 카드. 구획은 보더가 아니라 면으로 나눈다.
  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF4F5F7),
    surface: Color(0xFFFFFFFF),
    fill: Color(0xFFF4F5F7),
    line: Color(0xFFF0F2F4),
    ink: Color(0xFF111417),
    ink2: Color(0xFF3D464B),
    body: Color(0xFF4E585E),
    sub: Color(0xFF5B6469),
    label: Color(0xFF6B747A),
    muted: Color(0xFF9BA3A8),
    faint: Color(0xFFB5BBBF),
    disabled: Color(0xFFC3C9CD),
    onAccent: Color(0xFFFFFFFF),
    emphasis: Color(0xFF111417),
    accent: Color(0xFF0B9E82),
    accentDark: Color(0xFF0A8A72),
    accentSoft: Color(0xFFE9F7F3),
    gold: Color(0xFFE0A02C),
    goldSoft: Color(0xFFFBF6EC),
    alert: Color(0xFFF0483E),
    chipBlueBg: Color(0xFFEEF2FE),
    chipBlueFg: Color(0xFF3A62D8),
    chipAmberBg: Color(0xFFFFF3E4),
    chipAmberFg: Color(0xFFD5811A),
    photoA: Color(0xFFEDEFF1),
    photoB: Color(0xFFE4E7EA),
    photoGoldA: Color(0xFFF7EFDD),
    photoGoldB: Color(0xFFF0E5CB),
    silhouette: Color(0xFFDCE0E3),
    silhouetteGold: Color(0xFFEBDCBF),
    lockedGoldText: Color(0xFFD3C6A6),
    scrim: Color(0x9E111417),
    hairline: Color(0x0F111417),
  );

  /// 숯색 배경 위에 한 톤 밝은 카드.
  ///
  /// 라이트를 그대로 반전한 게 아니다. 어두운 면에서는 같은 채도라도 색이 더
  /// 튀어 보여서 주색을 #0B9E82 → #10B981 로 올리고(대비 확보), 반대로 회색
  /// 계단은 흰색 쪽으로 몰지 않고 #6B7280~#9CA3AF 사이에서 눌러 둔다.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF111417),
    surface: Color(0xFF1C2126),
    // 다크에서 fill 은 bg 와 같을 수 없다 — 카드(#1C2126) 위에 눌러 넣는
    // 면이라 카드보다 밝아야 눌린 것처럼 보인다.
    fill: Color(0xFF2D333B),
    line: Color(0xFF2D333B),
    ink: Color(0xFFFFFFFF),
    ink2: Color(0xFFE1E4E6),
    body: Color(0xFF9CA3AF),
    sub: Color(0xFF9CA3AF),
    label: Color(0xFF9CA3AF),
    muted: Color(0xFF6B7280),
    faint: Color(0xFF6B7280),
    disabled: Color(0xFF4B5563),
    onAccent: Color(0xFFFFFFFF),
    emphasis: Color(0xFF10B981),
    accent: Color(0xFF10B981),
    // 라이트에서는 주색의 "진한 끝"이지만 다크에서는 밝은 끝이어야 읽힌다.
    accentDark: Color(0xFF34D399),
    accentSoft: Color(0xFF1A3834),
    gold: Color(0xFFF59E0B),
    goldSoft: Color(0xFF3B2A10),
    alert: Color(0xFFF87171),
    chipBlueBg: Color(0xFF213045),
    chipBlueFg: Color(0xFF60A5FA),
    chipAmberBg: Color(0xFF3D3422),
    chipAmberFg: Color(0xFFFBBF24),
    photoA: Color(0xFF2D333B),
    photoB: Color(0xFF374151),
    photoGoldA: Color(0xFF78350F),
    photoGoldB: Color(0xFF92400E),
    silhouette: Color(0xFF4B5563),
    silhouetteGold: Color(0xFF92400E),
    lockedGoldText: Color(0xFFD97706),
    scrim: Color(0xB3000000),
    hairline: Color(0x0DFFFFFF),
  );
}
