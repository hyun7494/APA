import '../models/models.dart';

/// app-fishing 백엔드 계약 (기획서 4-2).
///
/// 구현체는 두 개다 — [MockFishingRepository](시드 데이터),
/// [RemoteFishingRepository](실제 `/fishing/**` 호출).
///
/// Rev 2에서 운세 호출이 빠지고 도감·조과 계약이 들어왔다.
abstract interface class FishingRepository {
  // ── 지수 ────────────────────────────────────────────────────
  /// GET /fishing/regions
  Future<List<RegionGroup>> fetchRegions();

  /// GET /fishing/regions/search?q=
  Future<List<RegionGroup>> searchRegions(String query);

  /// GET /fishing/spots?regionGroupId=
  Future<List<Spot>> fetchSpots(int regionGroupId);

  /// GET /fishing/spots/{id}
  Future<Spot> fetchSpot(int id);

  // ── 도감 ────────────────────────────────────────────────────
  /// GET /fishing/me/collection
  ///
  /// 어종 마스터 전체에 내 획득 상태를 얹어 내려준다. 비로그인이면
  /// 전 칸이 미등록인 마스터 도감이 온다 (기획서 5-5).
  Future<List<CollectionEntry>> fetchCollection();

  /// GET /fishing/species/{id} + 내 기록
  Future<CollectionEntry> fetchCollectionEntry(int speciesId);

  /// GET /fishing/me/catches?speciesId=
  Future<List<CatchRecord>> fetchCatches({int? speciesId});

  /// POST /fishing/me/catches
  Future<CatchResult> registerCatch(CatchDraft draft);

  /// DELETE /fishing/me/catches/{id}
  ///
  /// 기획서 3-3: 잘못 등록한 어종을 되돌릴 수 없으면 도감 전체의 신뢰가
  /// 무너지므로 삭제는 필수다. 마지막 기록이 지워지면 칸도 미등록으로 돌아간다.
  Future<void> deleteCatch(int id);

  // ── 게시판 · 마이 ───────────────────────────────────────────
  /// GET /fishing/board?tag=&regionGroupId=
  Future<List<Post>> fetchPosts({PostCategory? category, int? regionGroupId});

  /// GET /fishing/me/profile — 비로그인이면 null
  Future<Profile?> fetchProfile();
}
