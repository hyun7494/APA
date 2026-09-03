import '../models/models.dart';
import 'photo_picker.dart';

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

  /// GET /fishing/spots/featured — 홈 요약 카드에 쓸 **오늘 가장 좋은 포인트** 한 곳.
  ///
  /// 고르는 일은 서버가 한다. 한 곳을 보여주려고 51곳을 받아 갈 이유가 없다
  /// (위치 검색과 같은 이유). 포인트가 하나도 없으면 null 이다.
  Future<Spot?> fetchFeaturedSpot();

  /// 내 위치에서 가까운 포인트 — `GET /fishing/spots?lat=&lon=`.
  ///
  /// 거리 계산은 **서버가 한다.** 좌표는 서버에 있고, 앱이 쓰지도 않을 위경도를
  /// 포인트 수만큼 받아 갈 이유가 없다. 각 [Spot.distanceKm] 가 채워져 온다.
  Future<List<Spot>> fetchNearbySpots(double latitude, double longitude);

  /// 이름으로 포인트 검색 — `GET /fishing/spots?q=`.
  ///
  /// 지역 검색만으로는 `울릉` 을 쳐도 결과가 `동해` 라, 권역을 누른 뒤 14곳 중에서
  /// 다시 찾아야 했다. 검색어가 비면 빈 목록이다.
  Future<List<Spot>> searchSpots(String query);

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
  /// 기록 수정 — `PUT /fishing/me/catches/{id}` (계약서 3-7-3).
  ///
  /// [keepPhotoUrls] 는 **남길 장의 URL 목록**이고 순서가 그대로 간다.
  /// 새로 올리는 [CatchDraft.photos] 는 그 **뒤에** 붙는다 (서버 규칙).
  ///
  /// 빈 목록은 "사진을 다 뗀다" 는 뜻이라 **함부로 넘기면 안 된다.**
  /// 등록과 마찬가지로 인증샷은 최소 한 장이어야 하므로, 화면이 그걸 먼저 막는다.
  ///
  /// @throws [PostSubmitException] 서버가 거절했을 때 (남의 기록은 404)
  Future<CatchRecord> updateCatch(
    int id,
    CatchDraft draft, {
    required List<String> keepPhotoUrls,
  });

  Future<void> deleteCatch(int id);

  // ── 게시판 · 마이 ───────────────────────────────────────────
  /// GET /fishing/board?tag=&regionGroupId=
  Future<List<Post>> fetchPosts({PostCategory? category, int? regionGroupId});

  /// 내 글 고치기. 인증 필요 — 남의 글은 서버가 404 로 막는다.
  /// [photo] 를 안 주면 **기존 사진을 그대로 둔다** — 글자만 고치려고 사진을 다시
  /// 고르게 하면 안 된다.
  Future<PostDetail> updatePost({
    required int id,
    required PostCategory category,
    required String title,
    required String content,
    PickedPhoto? photo,
    int? regionGroupId,
  });

  /// 내 글 지우기. 댓글·좋아요는 서버가 함께 지운다.
  Future<void> deletePost(int id);

  /// 글 상세. 목록과 달리 본문 전체가 온다. 읽기는 비로그인도 된다.
  Future<PostDetail> fetchPost(int id);

  Future<List<Comment>> fetchComments(int postId);

  /// 댓글 쓰기. 인증 필요.
  Future<Comment> createComment(int postId, String content);

  /// 내 댓글 삭제. 인증 필요 — 남의 댓글은 서버가 404 로 막는다.
  Future<void> deleteComment(int commentId);

  /// 좋아요 토글. 인증 필요. 누른 뒤의 **수와 상태를 서버가 정해서** 돌려준다.
  Future<({int likeCount, bool likedByMe})> toggleLike(int postId);

  /// 글 신고. 인증 필요 — 내 글은 서버가 400 으로 막는다 (계약서 3-8).
  ///
  /// 신고가 몇 건 쌓였는지는 **일부러 안 받는다.** 그 수가 보이면 몇 건이면 글이
  /// 내려가는지 재 볼 수 있고, 여럿이 맞춰 특정 글을 노리는 데 쓰인다.
  ///
  /// @return 이미 신고해 둔 글이었으면 true. 두 번째 신고는 오류가 아니다 —
  ///         사용자가 보는 결과(이 글은 신고돼 있다)가 같아서 문구만 갈린다
  /// @throws [PostSubmitException] 서버가 거절했을 때
  Future<bool> reportPost(
    int postId, {
    required ReportReason reason,
    String? detail,
  });

  /// 글쓰기. 인증이 필요하다 — 서버가 작성자를 토큰에서 가져간다.
  ///
  /// @throws [PostSubmitException] 서버가 거절했을 때. 메시지를 그대로 띄우면 된다
  Future<Post> createPost({
    required PostCategory category,
    required String title,
    required String content,
    PickedPhoto? photo,
    /// 지역 게시판. null 이면 전체 게시판 글이다.
    int? regionGroupId,
  });

  /// GET /fishing/me/profile — 비로그인이면 null
  Future<Profile?> fetchProfile();

  /// GET /fishing/me/favorites — 즐겨찾는 권역. 비로그인이면 빈 목록이다.
  Future<List<RegionGroup>> fetchFavorites();

  /// PUT · DELETE /fishing/me/favorites/{regionGroupId} (계약서 3-7-5).
  ///
  /// ★ **토글이 아니라 원하는 상태를 보낸다.** 토글이면 응답이 유실돼 앱이 재시도할 때
  /// 도로 꺼진다 — 별을 한 번 눌렀는데 두 번 누른 결과가 된다. 별을 누르는 쪽은 언제나
  /// 원하는 최종 상태를 알고 있으므로 그걸 그대로 보낸다.
  ///
  /// 둘 다 **갱신된 전체 목록**을 돌려준다. 화면이 자기 쪽에서 더하고 빼며 상태를
  /// 지어내면 다른 기기에서 바꾼 것이 반영되지 않아 조금씩 어긋난다.
  Future<List<RegionGroup>> setFavorite(int regionGroupId, {required bool on});

  /// GET /fishing/users/{userId} — 남의 공개 프로필 (계약서 3-10).
  ///
  /// **게시판 활동만** 온다. 조과·도감·사진은 본인만 본다 (약관 10조 2항).
  /// 공개할 활동이 없으면 서버가 404 다.
  Future<PublicProfile> fetchPublicProfile(int userId);

  /// DELETE /fishing/me — 탈퇴 전에 이 서비스의 흔적을 정리한다 (계약서 3-9).
  /// 조과·사진은 지워지고, 글·댓글은 남되 글쓴이가 가려진다.
  Future<void> eraseMyData();
}

/// 글쓰기가 실패했을 때 화면에 그대로 띄울 수 있는 메시지.
///
/// 화면이 `DioException` 을 알지 않게 하려고 둔다 — 알게 되면 저장소를 갈아끼운
/// 테스트에서도 그 타입을 흉내내야 한다. `UnsupportedPhotoException` 과 같은 결이다.
class PostSubmitException implements Exception {
  const PostSubmitException(this.message);

  final String message;

  @override
  String toString() => message;
}
