import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/species.dart';
import '../services/login_gate.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
import '../widgets/collection_progress.dart';
import '../widgets/pill_chip.dart';
import '../widgets/reveal.dart';
import '../widgets/species_tile.dart';

/// 어류 도감 — 3열 그리드.
///
/// 등록된 칸은 내가 찍은 사진이 그대로 표지가 되고, 미등록 칸은 점선 +
/// 자물쇠로 남겨 "빈 칸"임을 숨기지 않는다.
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(filteredCollectionProvider);
    final summary = ref.watch(collectionSummaryProvider);
    final filter = ref.watch(collectionFilterProvider);
    final all = ref.watch(collectionProvider).valueOrNull;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Reveal(
            child: ScreenHeader(
              title: '어류 도감',
              actions: [
                IconTapButton(
                  icon: AppIcon.search,
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('어종 검색은 준비 중입니다')),
                  ),
                ),
                HeaderButton(
                  label: '등록',
                  icon: AppIcon.camera,
                  filled: true,
                  onPressed: () => requireLogin(
                    context,
                    ref,
                    destination: '/catch/new',
                    reason: '조과를 등록하려면 로그인이 필요해요.\n기록은 계정에 저장됩니다.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 진행도 카드
          Reveal(
            index: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screen,
              ),
              child: AppCard(
                radius: AppRadius.cardSmall,
                padding: const EdgeInsets.all(17),
                child: summary.when(
                  loading: () => const LoadingView(height: 70, lines: 2),
                  error: (e, _) =>
                      ErrorView(message: '도감을 불러오지 못했어요', error: e, height: 70),
                  data: (s) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${s.owned}',
                                    style: AppText.numberLarge,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '/ ${s.total} 종',
                                    style: AppText.numberMedium.copyWith(
                                      color: AppColors.faint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${s.percent}%',
                            style: AppText.rowLabel.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CollectionProgressBar(summary: s),
                      const SizedBox(height: 12),
                      CollectionLegend(summary: s),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 필터 칩
          Reveal(
            index: 2,
            child: ChipRow(
              children: [
                for (final f in CollectionFilter.values)
                  SquareChip(
                    // v2 칩에는 카운트 뱃지가 없다. 개수를 라벨에 붙여
                    // 칩 하나로 읽히게 한다.
                    label: all == null
                        ? f.label
                        : '${f.label} ${_countFor(f, all)}',
                    selected: filter == f,
                    onTap: () =>
                        ref.read(collectionFilterProvider.notifier).state = f,
                  ),
              ],
            ),
          ),

          Expanded(
            child: entries.when(
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.screen, 20, 22, 0),
                child: LoadingView(height: 240, lines: 6),
              ),
              error: (e, _) =>
                  ErrorView(message: '도감을 불러오지 못했어요', error: e, height: 240),
              data: (list) {
                if (list.isEmpty) {
                  return const ErrorView(
                    message: '조건에 맞는 어종이 없어요',
                    height: 240,
                  );
                }
                return GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    12,
                    AppSpacing.screen,
                    AppSpacing.navClearance,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 8,
                        // 정사각 타일 + 이름 2줄
                        childAspectRatio: 0.72,
                      ),
                  itemCount: list.length,
                  itemBuilder: (_, i) => Reveal(
                    index: i,
                    offset: 18,
                    child: SpeciesTile(
                      entry: list[i],
                      onTap: () =>
                          context.go('/collection/${list[i].species.id}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static int _countFor(CollectionFilter f, List<CollectionEntry> all) =>
      switch (f) {
        CollectionFilter.all => all.length,
        CollectionFilter.owned => all.where((e) => e.owned).length,
        CollectionFilter.rare => all.where((e) => e.species.rarity.isRare).length,
        CollectionFilter.locked => all.where((e) => !e.owned).length,
      };
}
