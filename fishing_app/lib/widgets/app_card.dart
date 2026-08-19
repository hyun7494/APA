import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'press_scale.dart';

/// 흰 카드 한 겹.
///
/// 이전 판의 이중 베젤(흰 카드 안의 회색 카드)을 없앴다. 회색 배경 위에
/// 흰 카드 하나 — 국내 앱이 공통으로 쓰는 두 겹 구조다. 테두리도 두지
/// 않는다. 구획은 보더가 아니라 면으로 나눈다.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppRadius.card,
    this.color = AppColors.surface,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}

/// 카드 안 구분선 — 좌우로 꽉 차게 긋는다.
class CardDivider extends StatelessWidget {
  const CardDivider({super.key, this.margin = EdgeInsets.zero});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: margin,
    color: AppColors.line,
  );
}

/// 지표 한 칸 — 아이콘+라벨 위, 값 아래. 홈 지수 카드의 수온·파고·풍속.
class MetricColumn extends StatelessWidget {
  const MetricColumn({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
  });

  final AppIcon icon;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final unitText = unit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            LineIcon(icon, size: 15, color: AppColors.muted, stroke: 1.5),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: AppText.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              text: value,
              style: AppText.numberMedium,
              children: unitText == null
                  ? null
                  : [
                      TextSpan(text: ' $unitText', style: AppText.unit),
                    ],
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

/// 라벨 · 값 한 줄이 구분선으로 이어지는 표.
///
/// 어종 상세의 첫 기록/제철/서식, 기록 추가 폼이 같은 문법을 쓴다.
class InfoRows extends StatelessWidget {
  const InfoRows({
    super.key,
    required this.rows,
    this.verticalPadding = 13,
  });

  final List<Widget> rows;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const CardDivider(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: verticalPadding),
            child: rows[i],
          ),
        ],
      ],
    );
  }
}

/// 표의 한 줄 — 왼쪽 라벨, 오른쪽 값(+선택적 화살표).
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.chevron = false,
    this.valueColor,
    this.onTap,
  });

  final String label;
  final String value;
  final String? unit;

  /// 누를 수 있는 행이면 오른쪽에 화살표를 둔다.
  final bool chevron;

  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unitText = unit;

    final row = Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppText.rowLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text.rich(
            TextSpan(
              text: value,
              style: AppText.rowValue.copyWith(color: valueColor),
              children: unitText == null
                  ? null
                  : [
                      TextSpan(
                        text: unitText,
                        style: AppText.rowValue.copyWith(
                          color: AppColors.label,
                        ),
                      ),
                    ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
        if (chevron) ...[
          const SizedBox(width: 8),
          const LineIcon(
            AppIcon.chevronRight,
            size: 17,
            color: AppColors.disabled,
            stroke: 1.6,
          ),
        ],
      ],
    );

    if (onTap == null) return row;
    return PressScale(onTap: onTap, scale: 0.99, child: row);
  }
}

/// 아이콘 칩이 붙은 작은 값 카드 — 홈의 물때 / 일출·일몰.
class IconValueCard extends StatelessWidget {
  const IconValueCard({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.label,
    required this.value,
  });

  final AppIcon icon;
  final Color iconBg;
  final Color iconFg;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppRadius.cardSmall,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppRadius.iconChip),
            ),
            child: Center(
              child: LineIcon(icon, size: 18, color: iconFg, stroke: 1.6),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppText.caption.copyWith(fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: AppText.numberMedium.copyWith(
                      fontSize: 15,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
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
