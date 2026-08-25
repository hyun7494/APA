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

/// 기록 하나 — 수정 화면이 쓴다.
///
/// 서버에 단건 조회가 없어서 내 기록 전체(`catchesProvider(null)`)에서 골라낸다.
/// 화면이 `extra` 로 받아 오게 하면 새로고침·딥링크로 들어왔을 때 빈손이 된다.
final catchProvider = FutureProvider.family<CatchRecord, int>((ref, id) async {
  final all = await ref.watch(catchesProvider(null).future);
  final found = all.where((c) => c.id == id).firstOrNull;
  if (found == null) {
    // 남의 기록이거나 방금 지운 기록이다. 서버도 이 둘을 404 로 합쳐서 낸다.
    throw StateError('기록을 찾을 수 없습니다: $id');
  }
  return found;
});

/// 조과 등록 화면의 어종 선택기가 쓰는 마스터 목록.
///
/// 도감과 달리 여기서는 미등록 어종도 전부 컬러로 보여준다 (기획서 5-4).
final speciesMasterProvider = Provider<List<Species>>((ref) => SpeciesSeed.all);

// ── 게시판 · 마이 ───────────────────────────────────────────────

final postsProvider = FutureProvider<List<Post>>((ref) {
  final category = ref.watch(selectedBoardTabProvider);
  // 좋아요·댓글 수와 likedByMe 가 보는 사람에 따라 다르다.
  ref.watch(postRevisionProvider);
  ref.watch(loggedInProvider);
  return ref.watch(fishingRepositoryProvider).fetchPosts(category: category);
});

/// 글 상세를 바꾼 뒤(좋아요·댓글) 화면을 새로 받아오기 위한 신호.
/// 조과 등록의 [collectionRevisionProvider] 와 같은 장치다.
final postRevisionProvider = StateProvider<int>((ref) => 0);

final postDetailProvider = FutureProvider.family<PostDetail, int>((ref, id) {
  ref.watch(postRevisionProvider);
  ref.watch(loggedInProvider);
  return ref.watch(fishingRepositoryProvider).fetchPost(id);
});

final commentsProvider = FutureProvider.family<List<Comment>, int>((ref, postId) {
  ref.watch(postRevisionProvider);
  ref.watch(loggedInProvider);
  return ref.watch(fishingRepositoryProvider).fetchComments(postId);
});

final profileProvider = FutureProvider<Profile?>((ref) {
  ref.watch(loggedInProvider);
  return ref.watch(fishingRepositoryProvider).fetchProfile();
});
