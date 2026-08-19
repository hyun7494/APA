import 'package:flutter/material.dart';

import '../models/species.dart';
import '../theme/app_theme.dart';

/// 도감 진행률 바.
///
/// 일반 등록분(틸)과 희귀 등록분(골드)을 한 트랙에 이어 붙여, 몇 종을
/// 채웠는지와 그중 희귀가 얼마인지를 막대 하나로 읽게 한다.
///
/// 값이 0에서 시작해 [AppMotion.settle] 커브로 자라난다 — 완성된 길이로
/// 그냥 나타나면 계기가 아니라 그림처럼 읽힌다.
class CollectionProgressBar extends StatelessWidget {
  const CollectionProgressBar({
    super.key,
    required this.summary,
    this.height = 10,
  });

  final CollectionSummary summary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = summary.total == 0 ? 1 : summary.total;
    final common = summary.commonOwned / total;
    final rare = summary.rareOwned / total;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.slow,
      curve: AppMotion.settle,
      builder: (context, t, _) => Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              flex: ((common * t) * 1000).round(),
              child: const ColoredBox(color: AppColors.accent),
            ),
            Expanded(
              flex: ((rare * t) * 1000).round(),
              child: const ColoredBox(color: AppColors.gold),
            ),
            // 남은 자리 — flex가 전부 0이 되면 Row가 깨지므로 최소 1을 준다
            Expanded(
              flex: (1000 - ((common + rare) * t * 1000).round()).clamp(1, 1000),
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 진행률 바 아래 범례 — 일반 / 희귀 / 미등록 개수.
class CollectionLegend extends StatelessWidget {
  const CollectionLegend({super.key, required this.summary});

  final CollectionSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Dot(color: AppColors.accent, label: '일반', value: summary.commonOwned),
        const SizedBox(width: 14),
        _Dot(color: AppColors.gold, label: '희귀', value: summary.rareOwned),
        const SizedBox(width: 14),
        _Dot(
          color: const Color(0xFFD3DAD5),
          label: '미등록',
          value: summary.locked,
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$label $value',
          style: AppText.caption.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}
