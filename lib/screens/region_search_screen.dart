import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/region_group.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
import '../widgets/rating_badge.dart';
import '../widgets/reveal.dart';

/// 지역 검색 — 검색창, 현재 위치로 찾기, 전체 지역 리스트.
class RegionSearchScreen extends ConsumerStatefulWidget {
  const RegionSearchScreen({super.key});

  @override
  ConsumerState<RegionSearchScreen> createState() => _RegionSearchScreenState();
}

class _RegionSearchScreenState extends ConsumerState<RegionSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(RegionGroup region) {
    ref.read(selectedRegionIdProvider.notifier).state = region.id;
    context.go('/score');
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(regionSearchProvider(_query));

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          BackRow(label: '낚시 지수', onTap: () => context.go('/score')),
          const SizedBox(height: 22),
          const Reveal(
            child: ScreenHeader(title: '지역 선택'),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                24,
                AppSpacing.screen,
                AppSpacing.navClearance,
              ),
              children: [
                Reveal(
                  index: 1,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const LineIcon(
                          AppIcon.search,
                          size: 17,
                          color: AppColors.faint,
                          stroke: 1.5,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            onChanged: (v) => setState(() => _query = v),
                            cursorColor: AppColors.accent,
                            style: AppText.body.copyWith(color: AppColors.ink),
                            decoration: const InputDecoration(
                              hintText: '지역 또는 포인트 검색',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.gap),
                Reveal(
                  index: 2,
                  child: PrimaryButton(
                    label: '현재 위치로 찾기',
                    icon: AppIcon.pin,
                    // 위치 권한·지오코딩은 백엔드 연동 단계에서 붙인다.
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('위치 기반 검색은 API 연동 후 지원됩니다'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.section),

                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _query.isEmpty ? '전체 지역' : '검색 결과',
                    style: AppText.sectionTitle,
                  ),
                ),

                results.when(
                  loading: () => const LoadingView(height: 160, lines: 4),
                  error: (e, _) =>
                      ErrorView(message: '지역을 불러오지 못했어요', error: e),
                  data: (list) {
                    if (list.isEmpty) {
                      return const ErrorView(message: '검색 결과가 없어요', height: 120);
                    }
                    return Column(
                      children: [
                        for (var i = 0; i < list.length; i++) ...[
                          if (i > 0) const SizedBox(height: AppSpacing.gap),
                          Reveal(
                            index: i + 3,
                            child: _RegionRow(
                              region: list[i],
                              onTap: () => _pick(list[i]),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionRow extends StatelessWidget {
  const _RegionRow({required this.region, required this.onTap});

  final RegionGroup region;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final temp = region.previewWaterTemp;
    final rating = region.previewRating;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  region.name,
                  style: AppText.sectionTitle.copyWith(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(region.area, style: AppText.caption),
              ],
            ),
          ),
          if (temp != null) ...[
            Text(
              '${temp.toStringAsFixed(1)}℃',
              style: AppText.numberMedium.copyWith(color: AppColors.muted),
            ),
            const SizedBox(width: 10),
          ],
          if (rating != null) RatingBadge(rating: rating, compact: true),
        ],
      ),
    );
  }
}
