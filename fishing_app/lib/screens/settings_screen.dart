import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
import '../widgets/reveal.dart';

/// 설정 — 지금은 화면 테마 한 항목뿐이다.
///
/// 알림·계정처럼 뒤에 붙을 항목이 있어서 카드 하나에 다 몰아넣지 않고
/// 섹션(라벨 + 카드) 문법으로 열어 뒀다.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Reveal(
            child: BackRow(label: '마이페이지', onTap: () => context.go('/profile')),
          ),
          const SizedBox(height: 14),
          const Reveal(index: 1, child: ScreenHeader(title: '설정')),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                22,
                AppSpacing.screen,
                AppSpacing.navClearance,
              ),
              children: [
                Reveal(
                  index: 2,
                  child: SectionLabel(label: '화면 테마', padded: false),
                ),
                const SizedBox(height: 12),
                Reveal(
                  index: 3,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        for (
                          var i = 0;
                          i < AppThemeMode.values.length;
                          i++
                        ) ...[
                          if (i > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Divider(),
                            ),
                          _ThemeOption(
                            mode: AppThemeMode.values[i],
                            selected: AppThemeMode.values[i] == mode,
                            onTap: () => ref
                                .read(themeModeProvider.notifier)
                                .select(AppThemeMode.values[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Reveal(
                  index: 4,
                  child: NoticeLine(
                    text: '시스템 설정을 따르면 기기가 밤 모드로 바뀔 때 앱도 함께 어두워집니다.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 테마 한 줄 — 아이콘 · 이름/설명 · 선택 표시.
///
/// 라디오 위젯 대신 오른쪽 체크 하나로 고른 것을 표시한다. 시안이 머티리얼
/// 컨트롤을 한 곳도 쓰지 않는다.
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final AppThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  AppIcon get _icon => switch (mode) {
    AppThemeMode.system => AppIcon.settings,
    AppThemeMode.light => AppIcon.sun,
    AppThemeMode.dark => AppIcon.moon,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? AppColors.accentSoft : AppColors.fill,
                borderRadius: BorderRadius.circular(AppRadius.iconChip),
              ),
              child: Center(
                child: LineIcon(
                  _icon,
                  size: 18,
                  color: selected ? AppColors.accent : AppColors.muted,
                  stroke: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(mode.label, style: AppText.sectionTitle),
                  const SizedBox(height: 3),
                  Text(mode.description, style: AppText.caption),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (selected)
              LineIcon(
                AppIcon.check,
                size: 18,
                color: AppColors.accent,
                stroke: 2,
              ),
          ],
        ),
      ),
    );
  }
}
