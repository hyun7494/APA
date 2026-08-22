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

  /// 내 글 고치기. 인증 필요 — 남의 글은 서버가 404 로 막는다.
  /// [photo] 를 안 주면 **기존 사진을 그대로 둔다** — 글자만 고치려고 사진을 다시
  /// 고르게 하면 안 된다.
  Future<PostDetail> updatePost({
    required int id,
    required PostCategory category,
    required String title,
    required String content,
    PickedPhoto? photo,
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

  /// 글쓰기. 인증이 필요하다 — 서버가 작성자를 토큰에서 가져간다.
  ///
  /// @throws [PostSubmitException] 서버가 거절했을 때. 메시지를 그대로 띄우면 된다
  Future<Post> createPost({
    required PostCategory category,
    required String title,
    required String content,
    PickedPhoto? photo,
  });

  /// GET /fishing/me/profile — 비로그인이면 null
  Future<Profile?> fetchProfile();
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
