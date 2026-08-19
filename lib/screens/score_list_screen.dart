import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/async_view.dart';
import '../widgets/pill_chip.dart';
import '../widgets/reveal.dart';
import '../widgets/spot_card.dart';

/// 낚시 지수 목록 — 지역 그룹 칩 + 선택 그룹의 포인트 카드.
class ScoreListScreen extends ConsumerWidget {
  const ScoreListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regions = ref.watch(regionsProvider);
    final spots = ref.watch(spotsProvider);
    final selectedId = ref.watch(selectedRegionIdProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Reveal(
            child: ScreenHeader(
              title: '낚시 지수',
              actions: [
                HeaderButton(
                  label: '지역',
                  icon: AppIcon.pin,
                  onPressed: () => context.go('/search'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Reveal(
            index: 1,
            child: regions.when(
              loading: () => const SizedBox(height: 44),
              error: (e, _) =>
                  ErrorView(message: '지역을 불러오지 못했어요', error: e, height: 44),
              data: (list) => ChipRow(
                children: [
                  for (final region in list)
                    SquareChip(
                      label: region.name,
                      selected: region.id == selectedId,
                      onTap: () => ref
                          .read(selectedRegionIdProvider.notifier)
                          .state = region.id,
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: spots.when(
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.screen, 24, 22, 0),
                child: LoadingView(height: 240, lines: 6),
              ),
              error: (e, _) =>
                  ErrorView(message: '포인트를 불러오지 못했어요', error: e, height: 240),
              data: (list) {
                if (list.isEmpty) {
                  return const ErrorView(
                    message: '이 지역에 등록된 포인트가 없어요',
                    height: 240,
                  );
                }
                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    14,
                    AppSpacing.screen,
                    AppSpacing.navClearance,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.gap),
                  itemBuilder: (_, i) => Reveal(
                    // 칩 줄 다음부터 이어지도록 순번을 2에서 시작한다
                    index: i + 2,
                    child: SpotCard(
                      spot: list[i],
                      onOpen: () => context.go('/score/${list[i].id}'),
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
}
