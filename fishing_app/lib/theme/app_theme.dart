import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_typography.dart';

export 'app_colors.dart';
export 'app_icons.dart';
export 'app_motion.dart';
export 'app_palette.dart';
export 'app_typography.dart';

/// DEEP TIDE v2 — 앱 전역 ThemeData.
///
/// [build] 는 넘겨받은 팔레트로 한 벌을 짠다. 라이트/다크가 같은 코드를 타므로
/// 한쪽에만 반영되는 설정이 생기지 않는다.
abstract final class AppTheme {
  /// 상태 표시줄·네비게이션 바. 배경이 어두워지면 아이콘은 밝아져야 한다.
  static SystemUiOverlayStyle get systemOverlay =>
      overlayFor(AppColors.palette);

  static SystemUiOverlayStyle overlayFor(AppPalette palette) {
    final dark = palette.isDark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: palette.surface,
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
    );
  }

  static ThemeData build(AppPalette palette) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: palette.accent,
            brightness: palette.brightness,
          ).copyWith(
            primary: palette.accent,
            onPrimary: palette.onAccent,
            surface: palette.surface,
            onSurface: palette.ink,
          ),
      scaffoldBackgroundColor: palette.bg,
    );

    return base.copyWith(
      textTheme: GoogleFonts.gothicA1TextTheme(
        base.textTheme,
      ).apply(bodyColor: palette.ink, displayColor: palette.ink),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.appBarTitle,
        systemOverlayStyle: overlayFor(palette),
      ),
      // 다크에서 잉크색(흰색) 잉크는 눌린 자리가 하얗게 뜬다 — 라이트와 같은
      // 값을 쓰되 색만 팔레트에서 가져온다.
      splashColor: palette.ink.withValues(alpha: 0.05),
      highlightColor: palette.ink.withValues(alpha: 0.03),
      // 구획은 보더가 아니라 면으로 나눈다. Divider는 카드 안에서만 쓴다.
      dividerTheme: DividerThemeData(
        color: palette.line,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        // 라이트에서는 배경 위에 어두운 스낵바, 다크에서는 반대로 카드보다
        // 한 톤 밝은 면이어야 눈에 띈다.
        backgroundColor: palette.isDark ? palette.fill : palette.ink,
        contentTextStyle: AppText.bodySmall.copyWith(
          color: palette.isDark ? palette.ink : palette.onAccent,
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.navClearance - 20,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.chip)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        hintStyle: AppText.rowValue.copyWith(color: palette.disabled),
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    );
  }
}
