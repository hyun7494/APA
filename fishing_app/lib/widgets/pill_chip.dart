import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'press_scale.dart';

/// 필터 칩 — 라운드 사각. (머티리얼의 FilterChip과 이름이 겹치지 않게 SquareChip)
///
/// 시안이 알약을 버리고 r10 사각을 쓴다. 선택된 칩은 잉크색으로 채우고,
/// 나머지는 배경과 같은 회색 면으로 눌러 둔다.
class SquareChip extends StatelessWidget {
  const SquareChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.95,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.state,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.emphasis : AppColors.fill,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: AnimatedDefaultTextStyle(
          duration: AppMotion.fast,
          curve: AppMotion.state,
          style: AppText.chip.copyWith(
            color: selected ? AppColors.onAccent : AppColors.sub,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// 가로 스크롤 칩 줄.
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

/// 누를 수 없는 알약 배지 — 추천 어종, 즐겨찾는 지역.
class StaticPill extends StatelessWidget {
  const StaticPill({
    super.key,
    required this.label,
    this.background,
    this.foreground,
  });

  final String label;

  /// 생략하면 눌린 회색 면 + 보조 본문색.
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? AppColors.fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppText.badge.copyWith(color: foreground ?? AppColors.sub),
      ),
    );
  }
}
