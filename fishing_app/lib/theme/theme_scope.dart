import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/theme_controller.dart';
import 'app_theme.dart';

/// 고른 테마 + 기기 설정 → 팔레트를 정하고, 바뀌면 트리를 다시 그린다.
///
/// 이 앱의 색은 [AppColors] 정적 이름으로 불린다 (`AppColors.ink`). 편하지만
/// `Theme.of(context)` 를 타지 않아서, 팔레트를 갈아끼워도 Flutter 는 누가
/// 그 색을 쓰는지 알지 못한다 — 설정 화면만 바뀌고 다른 탭은 예전 색으로
/// 남는다. 그래서 팔레트가 바뀐 프레임 뒤에 엘리먼트 트리를 훑으며 전부
/// `markNeedsBuild` 한다. 위젯을 새로 만드는 게 아니라 다시 그리기만 하므로
/// 네비게이션 스택도, 스크롤 위치도, 입력 중이던 폼도 그대로 남는다.
class ThemeScope extends ConsumerWidget {
  const ThemeScope({super.key, required this.builder});

  final Widget Function(BuildContext context, ThemeData theme) builder;

  /// 고른 모드와 기기 밝기로 팔레트 한 벌을 고른다.
  static AppPalette resolve(AppThemeMode mode, Brightness platform) =>
      switch (mode) {
        AppThemeMode.light => AppPalette.light,
        AppThemeMode.dark => AppPalette.dark,
        AppThemeMode.system =>
          platform == Brightness.dark ? AppPalette.dark : AppPalette.light,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    // 시스템 설정을 따를 때 기기가 밤 모드로 넘어가면 이 값이 바뀌면서
    // 이 위젯이 다시 빌드된다.
    final platform = MediaQuery.platformBrightnessOf(context);
    final palette = resolve(mode, platform);

    if (AppColors.use(palette)) _repaintEverything();

    return builder(context, AppTheme.build(palette));
  }

  static void _repaintEverything() {
    // 빌드 도중에는 이미 그려진 엘리먼트를 더럽힐 수 없다. 프레임이 끝난 뒤로 미룬다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void visit(Element element) {
        element.markNeedsBuild();
        element.visitChildren(visit);
      }

      WidgetsBinding.instance.rootElement?.visitChildren(visit);
    });
  }
}
