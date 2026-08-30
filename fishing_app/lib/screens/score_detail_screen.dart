import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/spot.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
import '../widgets/pill_chip.dart';
import '../widgets/rating_badge.dart';
import '../widgets/reveal.dart';

/// 낚시 지수 상세 — 등급 링, 2x2 지표, 물때·일출, 시간대별 조황, 추천 어종.
class ScoreDetailScreen extends ConsumerWidget {
  const ScoreDetailScreen({super.key, required this.spotId});

  final int spotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spot = ref.watch(spotProvider(spotId));

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          BackRow(label: '낚시 지수', onTap: () => context.go('/score')),
          Expanded(
            child: spot.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.screen),
                child: LoadingView(height: 320, lines: 7),
              ),
              error: (e, _) =>
                  ErrorView(message: '포인트를 불러오지 못했어요', error: e, height: 320),
              data: (s) => _Body(spot: s),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        20,
        AppSpacing.screen,
        AppSpacing.navClearance,
      ),
      children: [
        Reveal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(spot.regionName, style: AppText.caption),
              const SizedBox(height: 6),
              Text(spot.name, style: AppText.screenTitle),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // 등급 + 지표를 한 장에 담는다. v2는 지표를 개별 카드로 흩지 않고
        // 카드 하나 안의 열로 세운다 — 카드 수가 줄어 화면이 조용해진다.
        Reveal(
          index: 1,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        spot.rating.label,
                        style: AppText.ratingHuge.copyWith(
                          color: spot.rating.foreground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: RatingScoreBadge(rating: spot.rating),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(spot.comment, style: AppText.body),
                const SizedBox(height: 20),
                const CardDivider(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: MetricColumn(
                        icon: AppIcon.thermometer,
                        label: '수온',
                        value: spot.waterTemp.toStringAsFixed(1),
                        unit: '℃',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MetricColumn(
                        icon: AppIcon.swell,
                        label: '파고',
                        value: spot.waveHeight.toStringAsFixed(1),
                        unit: 'm',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MetricColumn(
                        icon: AppIcon.wind,
                        label: '풍속',
                        value: spot.windSpeed.toStringAsFixed(1),
                        unit: '㎧',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MetricColumn(
                        icon: AppIcon.sun,
                        label: '날씨',
                        value: spot.weather,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.gap),

        // 물때 · 일출·일몰
        Reveal(
          index: 4,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            child: Column(
              children: [
                _InfoRow(
                  icon: AppIcon.moon,
                  color: AppColors.chipBlueFg,
                  label: '물때',
                  value: spot.tideInfo,
                ),
                const Divider(),
                _InfoRow(
                  icon: AppIcon.sunrise,
                  color: AppColors.accent,
                  label: '일출 · 일몰',
                  value: spot.sunriseSunset,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.section),

        // 예보가 없으면 카드를 통째로 뺀다. 빈 그래프를 남겨 두면 "온종일 조황 0" 으로
        // 읽히고, 그러고도 "06시 최적" 이라는 문구가 붙어 스스로를 반박한다.
        if (spot.hourlyForecast.isNotEmpty) ...[
          Reveal(index: 5, child: _HourlyCard(values: spot.hourlyForecast)),
          const SizedBox(height: AppSpacing.section),
        ],

        // 어종을 '-' 하나로만 주는 먼바다 해역이 있다 (인천항 서측·안흥항 등 17곳).
        // 파서가 그걸 걸러내면 목록이 비는데, 그때 제목만 남으면 빠진 것처럼 보인다.
        if (spot.recommendedFish.isNotEmpty) ...[
          Reveal(
            index: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('추천 어종', style: AppText.sectionTitle),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final fish in spot.recommendedFish)
                      StaticPill(label: fish),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
        ],

        const Reveal(
          index: 7,
          child: NoticeLine(
            text: '참고용 정보이며 실제 출조 여부는 현장 상황을 확인하세요.',
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final AppIcon icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          LineIcon(icon, size: 16, color: color, stroke: 1.4),
          const SizedBox(width: 11),
          Expanded(child: Text(label, style: AppText.rowLabel)),
          Text(
            value,
            style: AppText.numberMedium.copyWith(color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

/// 시간대별 조황 예상 — 6구간 막대그래프.
///
/// ⚠️ [values] 가 비어 있으면 **이 위젯을 만들지 말 것**. 호출부가 카드째로 감춘다.
/// 값이 없는 그래프는 "온종일 조황 0" 과 구별되지 않는다.
class _HourlyCard extends StatelessWidget {
  const _HourlyCard({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    // 가장 높은 구간만 살리고 나머지는 눌러서, 언제 나가야 하는지가
    // 그래프를 읽지 않아도 한눈에 들어오게 한다.
    final peak = values.indexOf(values.reduce((a, b) => a > b ? a : b));

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '시간대별 조황 예상',
                  style: AppText.cardLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${Spot.hourLabels[peak]} 최적',
                style: AppText.caption.copyWith(color: AppColors.accentDark),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _Bar(
                      value: values[i],
                      label: Spot.hourLabels[i].replaceAll('시', ''),
                      highlighted: i == peak,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.label,
    required this.highlighted,
  });

  final int value;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted
        ? AppColors.accent
        : AppColors.accent.withValues(alpha: 0.22);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: (value / 100).clamp(0.0, 1.0)),
      duration: AppMotion.slow,
      curve: AppMotion.settle,
      builder: (context, t, _) => Column(
        children: [
          Text(
            '$value',
            style: AppText.badgeSmall.copyWith(
              color: highlighted ? AppColors.accentDark : AppColors.faint,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: FractionallySizedBox(
              alignment: Alignment.bottomCenter,
              heightFactor: t,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 26),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            style: AppText.badgeSmall.copyWith(
              color: highlighted ? AppColors.body : AppColors.faint,
            ),
          ),
        ],
      ),
    );
  }
}
