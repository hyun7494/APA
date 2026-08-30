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

/// 지수 목록에서 사용자가 **직접 고른** 지역 그룹 id. 아직 안 골랐으면 null 이다.
///
/// ⚠️ 초기값을 특정 id 로 박으면 안 된다. 예전에는 `1`(부산 기장) 이었는데 V14 가 지역을
/// 권역으로 갈아엎으면서 그 id 가 사라져, 앱을 켜면 **아무 칩도 안 눌린 채 목록이 비었다.**
/// 어느 id 가 살아 있는지는 서버가 정한다 — 여기서 고르지 말고 [effectiveRegionIdProvider]
/// 가 목록의 첫 그룹으로 떨어지게 한다.
final selectedRegionIdProvider = StateProvider<int?>((ref) => null);

/// 실제로 보여줄 지역 — 고른 것이 있으면 그것, 없으면 **목록의 첫 그룹**이다.
///
/// 지역 목록을 아직 못 받았으면 null 이고, 그때는 포인트를 부르지 않는다.
final effectiveRegionIdProvider = Provider<int?>((ref) {
  final picked = ref.watch(selectedRegionIdProvider);
  final regions = ref.watch(regionsProvider).valueOrNull;

  // 고른 지역이 목록에 없을 수도 있다 (서버가 지역을 갈아엎은 뒤 앱이 살아 있는 경우).
  // 그때도 첫 그룹으로 물러선다 — 빈 화면보다 낫다.
  if (picked != null && (regions == null || regions.any((r) => r.id == picked))) {
    return picked;
  }
  return regions == null || regions.isEmpty ? null : regions.first.id;
});

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
final spotsProvider = FutureProvider<List<Spot>>((ref) async {
  final regionId = ref.watch(effectiveRegionIdProvider);
  // 지역 목록을 아직 못 받았다. 아무 id 나 넣어 부르면 엉뚱한 지역이 잠깐 뜬다.
  if (regionId == null) return const [];
  return ref.watch(fishingRepositoryProvider).fetchSpots(regionId);
});

/// 내 위치에서 가까운 포인트. 좌표가 정해진 뒤에만 부른다.
final nearbySpotsProvider =
    FutureProvider.family<List<Spot>, ({double lat, double lon})>(
  (ref, at) =>
      ref.watch(fishingRepositoryProvider).fetchNearbySpots(at.lat, at.lon),
);

/// 검색어에 이름이 걸리는 포인트. 검색 화면이 **포인트를 바로 고르게** 하려고 쓴다.
final spotSearchProvider = FutureProvider.family<List<Spot>, String>(
  (ref, query) => ref.watch(fishingRepositoryProvider).searchSpots(query),
);

final spotProvider = FutureProvider.family<Spot, int>(
  (ref, id) => ref.watch(fishingRepositoryProvider).fetchSpot(id),
);

/// 홈 요약 카드에 쓸 대표 포인트 1곳 — **오늘 가장 좋은 곳**.
///
/// 예전엔 "첫 지역의 첫 포인트" 였다. 권역이 4개에 51곳이 된 뒤로 그건 *id 가 가장
/// 작은 곳* 이라는 뜻밖에 없었고, 화면이 "오늘 출조, 어떠세요?" 라고 묻고는 임의의
/// 한 곳을 보여 줬다.
///
/// 고르는 일은 서버가 한다 — 요청도 한 번뿐이다(예전엔 지역 목록 → 포인트 목록으로
/// 두 번이었다). 기준은 `SpotService.findFeatured` 에 있다.
final featuredSpotProvider = FutureProvider<Spot?>(
  (ref) => ref.watch(fishingRepositoryProvider).fetchFeaturedSpot(),
);

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

/// 홈이 보여주는 최근 조황 글.
///
/// ⚠️ [postsProvider] 를 그대로 쓰면 안 된다 — 그쪽은 게시판 탭([selectedBoardTabProvider])을
/// 구독하므로, 사용자가 게시판에서 `질문` 탭을 골라 둔 채 홈에 오면 **홈에도 질문 글이 뜬다.**
/// 홈은 언제나 조황이다.
final recentCatchPostsProvider = FutureProvider<List<Post>>((ref) async {
  ref.watch(postRevisionProvider);
  ref.watch(loggedInProvider);

  final posts = await ref
      .watch(fishingRepositoryProvider)
      .fetchPosts(category: PostCategory.catchReport);
  // 서버도 목도 최신순으로 준다. 홈은 맨 앞 몇 개만 쓴다.
  return posts.take(3).toList();
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
