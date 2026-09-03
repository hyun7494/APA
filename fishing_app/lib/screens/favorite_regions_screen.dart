import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
import '../widgets/rating_badge.dart';
import '../widgets/reveal.dart';

/// 즐겨찾는 권역 고르기 (계약서 3-7-5). 마이페이지에서 들어온다.
///
/// ★ **여기서 고른 권역이 낚시 지수 화면의 기본이 된다.** 그게 이 기능이 하는 일이다 —
/// 표시만 하고 아무 일도 안 하는 값이면 굳이 고르게 할 이유가 없다
/// (`providers.dart` 의 [effectiveRegionIdProvider]).
///
/// 권역이 넷뿐이라 검색도 페이지도 없다. 전부 한 화면에 놓고 북마크를 누르게 한다.
class FavoriteRegionsScreen extends ConsumerStatefulWidget {
  const FavoriteRegionsScreen({super.key});

  @override
  ConsumerState<FavoriteRegionsScreen> createState() =>
      _FavoriteRegionsScreenState();
}

class _FavoriteRegionsScreenState extends ConsumerState<FavoriteRegionsScreen> {
  /// 지금 서버에 보내고 있는 권역. 그 줄만 잠근다 —
  /// 화면 전체를 잠그면 다른 권역을 누르려던 사람이 이유 없이 막힌다.
  int? _pending;

  Future<void> _toggle(RegionGroup region, bool isFavorite) async {
    if (_pending != null) return;
    setState(() => _pending = region.id);

    try {
      await ref
          .read(fishingRepositoryProvider)
          .setFavorite(region.id, on: !isFavorite);

      // 즐겨찾기가 바뀌면 마이페이지의 개수·칩과 지수 화면의 기본 권역이 함께
      // 달라진다. 화면마다 따로 새로 고치게 두면 어딘가는 반드시 빠뜨린다.
      ref.invalidate(favoritesProvider);
      ref.invalidate(profileProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('즐겨찾기를 바꾸지 못했어요. 잠시 후 다시 시도해 주세요')),
      );
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final regions = ref.watch(regionsProvider);
    final favorites = ref.watch(favoritesProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          BackRow(
            label: '마이',
            onTap: () => context.canPop() ? context.pop() : context.go('/profile'),
          ),
          Expanded(
            child: regions.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.screen),
                child: LoadingView(height: 260, lines: 4),
              ),
              error: (e, _) => ErrorView(
                message: '지역을 불러오지 못했어요',
                error: e,
                height: 260,
              ),
              data: (list) => _body(list, favorites.valueOrNull ?? const []),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(List<RegionGroup> regions, List<RegionGroup> favorites) {
    final favoriteIds = favorites.map((r) => r.id).toSet();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        20,
        AppSpacing.screen,
        AppSpacing.navClearance,
      ),
      children: [
        Reveal(child: Text('즐겨찾는 지역', style: AppText.screenTitle)),
        const SizedBox(height: 8),
        Reveal(
          index: 1,
          child: Text(
            '고른 지역이 낚시 지수 화면에 먼저 열려요.',
            style: AppText.body,
          ),
        ),
        const SizedBox(height: AppSpacing.gap),
        for (var i = 0; i < regions.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Reveal(
            index: 2 + i,
            child: _RegionToggle(
              region: regions[i],
              isFavorite: favoriteIds.contains(regions[i].id),
              busy: _pending == regions[i].id,
              onTap: () => _toggle(
                regions[i],
                favoriteIds.contains(regions[i].id),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 권역 한 줄 + 북마크. 지역 검색 화면의 `_RegionRow` 와 모양을 맞추되 북마크가 붙는다.
class _RegionToggle extends StatelessWidget {
  const _RegionToggle({
    required this.region,
    required this.isFavorite,
    required this.busy,
    required this.onTap,
  });

  final RegionGroup region;
  final bool isFavorite;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            if (region.previewRating != null) ...[
              RatingBadge(rating: region.previewRating!, compact: true),
              const SizedBox(width: 12),
            ],
            // ⚠️ **상태를 색으로만 알리면 안 된다.** 화면을 못 보는 사람에게는
            //    켜짐/꺼짐이 아예 전달되지 않는다 — 실제로 접근성 트리에 줄 이름과
            //    등급만 나오고 즐겨찾기 여부는 한 글자도 없었다.
            Semantics(
              label: isFavorite ? '즐겨찾기됨' : '즐겨찾기 안 함',
              child: SizedBox(
                // 보내는 동안 아이콘을 그대로 두면 눌린 게 먹혔는지 알 수 없고,
                // 자리를 비우면 줄이 덜컥거린다. 같은 크기로 바꿔 끼운다.
                width: 22,
                height: 22,
                child: busy
                    ? const Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    // 채워진 변형이 따로 없다 — 좋아요 칩과 같은 규칙으로 색이
                    // 상태를 거든다 (`post_detail_screen` 의 하트).
                    : LineIcon(
                        AppIcon.bookmark,
                        size: 22,
                        color: isFavorite ? AppColors.accent : AppColors.faint,
                        stroke: isFavorite ? 2.0 : 1.6,
                      ),
              ),
            ),
          ],
      ),
    );
  }
}
