import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/species_seed.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'auth_controller.dart';
import 'fishing_repository.dart';
import 'mock_fishing_repository.dart';
import 'remote_fishing_repository.dart';

/// 더미 ↔ 실 API 전환 스위치.
///
/// 기본은 더미(app-fishing 미착수). 백엔드가 뜨면:
/// `flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://10.0.2.2:8086`
const useMockData = bool.fromEnvironment('USE_MOCK', defaultValue: true);

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final fishingRepositoryProvider = Provider<FishingRepository>((ref) {
  if (useMockData) return MockFishingRepository();
  return RemoteFishingRepository(ref.watch(apiClientProvider));
});

// ── 화면이 구독하는 상태 ────────────────────────────────────────

/// 지수 목록에서 선택된 지역 그룹 id. 초기값은 첫 그룹(부산 기장).
final selectedRegionIdProvider = StateProvider<int>((ref) => 1);

/// 게시판 탭. null = 전체
final selectedBoardTabProvider = StateProvider<PostCategory?>((ref) => null);

/// 도감 필터.
enum CollectionFilter {
  all('전체'),
  owned('등록'),
  rare('희귀'),
  locked('미등록');

  const CollectionFilter(this.label);

  final String label;
}

final collectionFilterProvider = StateProvider<CollectionFilter>(
  (ref) => CollectionFilter.all,
);

// ── 지수 ────────────────────────────────────────────────────────

final regionsProvider = FutureProvider<List<RegionGroup>>(
  (ref) => ref.watch(fishingRepositoryProvider).fetchRegions(),
);

final regionSearchProvider = FutureProvider.family<List<RegionGroup>, String>(
  (ref, query) => ref.watch(fishingRepositoryProvider).searchRegions(query),
);

/// 현재 선택된 지역의 포인트 목록.
final spotsProvider = FutureProvider<List<Spot>>((ref) {
  final regionId = ref.watch(selectedRegionIdProvider);
  return ref.watch(fishingRepositoryProvider).fetchSpots(regionId);
});

final spotProvider = FutureProvider.family<Spot, int>(
  (ref, id) => ref.watch(fishingRepositoryProvider).fetchSpot(id),
);

/// 홈 요약 카드에 쓸 대표 포인트 1곳 — 첫 지역의 첫 포인트.
final featuredSpotProvider = FutureProvider<Spot?>((ref) async {
  final repo = ref.watch(fishingRepositoryProvider);
  final regions = await repo.fetchRegions();
  if (regions.isEmpty) return null;
  final spots = await repo.fetchSpots(regions.first.id);
  return spots.isEmpty ? null : spots.first;
});

// ── 도감 ────────────────────────────────────────────────────────

/// 조과를 등록하면 올려서 도감·진행도·기록을 한꺼번에 새로고침한다.
final collectionRevisionProvider = StateProvider<int>((ref) => 0);

final collectionProvider = FutureProvider<List<CollectionEntry>>((ref) {
  ref.watch(collectionRevisionProvider);
  ref.watch(loggedInProvider);
  return ref.watch(fishingRepositoryProvider).fetchCollection();
});

/// 필터가 적용된 도감 목록.
final filteredCollectionProvider = Provider<AsyncValue<List<CollectionEntry>>>((
  ref,
) {
  final filter = ref.watch(collectionFilterProvider);
  return ref.watch(collectionProvider).whenData(
    (list) => switch (filter) {
      CollectionFilter.all => list,
      CollectionFilter.owned => list.where((e) => e.owned).toList(),
      CollectionFilter.rare =>
        list.where((e) => e.species.rarity.isRare).toList(),
      CollectionFilter.locked => list.where((e) => !e.owned).toList(),
    },
  );
});

/// 홈·도감·마이가 공유하는 진행도 요약.
final collectionSummaryProvider = Provider<AsyncValue<CollectionSummary>>((ref) {
  final now = DateTime.now();
  return ref.watch(collectionProvider).whenData((list) {
    final owned = list.where((e) => e.owned).toList();
    return CollectionSummary(
      total: list.length,
      owned: owned.length,
      rareOwned: owned.where((e) => e.species.rarity.isRare).length,
      newThisMonth: owned
          .where(
            (e) =>
                e.firstCaughtAt != null &&
                e.firstCaughtAt!.year == now.year &&
                e.firstCaughtAt!.month == now.month,
          )
          .length,
    );
  });
});

final collectionEntryProvider =
    FutureProvider.family<CollectionEntry, int>((ref, speciesId) {
      ref.watch(collectionRevisionProvider);
      ref.watch(loggedInProvider);
      return ref
          .watch(fishingRepositoryProvider)
          .fetchCollectionEntry(speciesId);
    });

/// 어종별 내 기록. speciesId가 null이면 전체.
final catchesProvider =
    FutureProvider.family<List<CatchRecord>, int?>((ref, speciesId) {
      ref.watch(collectionRevisionProvider);
      ref.watch(loggedInProvider);
      return ref
          .watch(fishingRepositoryProvider)
          .fetchCatches(speciesId: speciesId);
    });

/// 조과 등록 화면의 어종 선택기가 쓰는 마스터 목록.
///
/// 도감과 달리 여기서는 미등록 어종도 전부 컬러로 보여준다 (기획서 5-4).
final speciesMasterProvider = Provider<List<Species>>((ref) => SpeciesSeed.all);

// ── 게시판 · 마이 ───────────────────────────────────────────────

final postsProvider = FutureProvider<List<Post>>((ref) {
  final category = ref.watch(selectedBoardTabProvider);
  return ref.watch(fishingRepositoryProvider).fetchPosts(category: category);
});

final profileProvider = FutureProvider<Profile?>((ref) {
  ref.watch(loggedInProvider);
  return ref.watch(fishingRepositoryProvider).fetchProfile();
});
