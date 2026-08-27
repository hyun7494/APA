import '../data/catch_seed.dart';
import '../data/mock_data.dart';
import '../data/species_seed.dart';
import '../models/models.dart';
import 'fishing_repository.dart';
import 'photo_picker.dart';

/// 시드 데이터로 응답하는 구현.
/// 백엔드 app-fishing이 뜨기 전까지 기본값이다.
///
/// 도감은 서버가 합쳐주는 형태지만, 여기서는 어종 마스터와 조과 기록을
/// 클라이언트에서 합쳐 [CollectionEntry]를 만든다.
class MockFishingRepository implements FishingRepository {
  MockFishingRepository();

  /// 로딩 상태가 실제로 보이도록 짧은 지연을 준다.
  static const _latency = Duration(milliseconds: 220);

  /// 등록/삭제가 화면에 반영되도록 들고 있는 목록. 실제 구현에서는 서버가 소유한다.
  ///
  /// static이 아니라 인스턴스 필드다 — static으로 두면 위젯 테스트끼리
  /// 등록 결과를 공유해서 실행 순서에 따라 결과가 달라진다.
  final List<CatchRecord> _catches = [...CatchSeed.all];

  /// 글쓰기가 목록에 반영되도록 들고 있는다 — [_catches] 와 같은 이유다.
  final List<Post> _posts = [...MockData.posts];

  @override
  Future<List<RegionGroup>> fetchRegions() async {
    await Future.delayed(_latency);
    return MockData.regions;
  }

  @override
  Future<List<RegionGroup>> searchRegions(String query) async {
    await Future.delayed(_latency);
    final q = query.trim();
    if (q.isEmpty) return MockData.regions;

    // 지역명·시도명뿐 아니라 **그 지역의 포인트 이름**도 본다 (서버 `RegionRepository.search`
    // 와 같은 규칙). 검색창 안내가 "지역 또는 포인트 검색" 인데 `학리` 가 안 걸렸었다 —
    // 사람은 자기가 아는 포인트 이름으로 찾는다.
    return MockData.regions.where((r) {
      if (r.name.contains(q) || r.area.contains(q)) return true;
      return MockData.spots
          .any((s) => s.regionGroupId == r.id && s.name.contains(q));
    }).toList();
  }

  @override
  Future<List<Spot>> fetchSpots(int regionGroupId) async {
    await Future.delayed(_latency);
    return MockData.spots.where((s) => s.regionGroupId == regionGroupId).toList();
  }

  @override
  Future<Spot> fetchSpot(int id) async {
    await Future.delayed(_latency);
    return MockData.spots.firstWhere(
      (s) => s.id == id,
      orElse: () => MockData.spots.first,
    );
  }

  @override
  Future<List<CollectionEntry>> fetchCollection() async {
    await Future.delayed(_latency);
    return _buildCollection();
  }

  @override
  Future<CollectionEntry> fetchCollectionEntry(int speciesId) async {
    await Future.delayed(_latency);
    return _entryFor(
      SpeciesSeed.all.firstWhere(
        (s) => s.id == speciesId,
        orElse: () => SpeciesSeed.all.first,
      ),
    );
  }

  @override
  Future<List<CatchRecord>> fetchCatches({int? speciesId}) async {
    await Future.delayed(_latency);
    final list = _catches
        .where((c) => speciesId == null || c.speciesId == speciesId)
        .toList();
    list.sort((a, b) => b.caughtAt.compareTo(a.caughtAt));
    return list;
  }

  @override
  Future<CatchResult> registerCatch(CatchDraft draft) async {
    await Future.delayed(_latency);

    final species = SpeciesSeed.all.firstWhere((s) => s.id == draft.speciesId);
    final firstCatch = !_catches.any((c) => c.speciesId == draft.speciesId);

    final record = CatchRecord(
      id: (_catches.map((c) => c.id).fold(0, (a, b) => a > b ? a : b)) + 1,
      speciesId: species.id,
      speciesName: species.name,
      // 목 모드에는 사진을 올릴 서버가 없다. 시드와 같은 규칙으로 비워 두고
      // 화면은 줄무늬 플레이스홀더를 그린다.
      lengthCm: draft.lengthCm,
      caughtAt: draft.caughtAt,
      spotName: draft.spotName,
      memo: draft.memo,
    );
    _catches.add(record);

    final owned = _catches.map((c) => c.speciesId).toSet().length;
    return CatchResult(
      record: record,
      firstCatch: firstCatch,
      ownedCount: owned,
      totalCount: SpeciesSeed.all.length,
    );
  }

  @override
  Future<CatchRecord> updateCatch(
    int id,
    CatchDraft draft, {
    required List<String> keepPhotoUrls,
  }) async {
    await Future.delayed(_latency);

    final i = _catches.indexWhere((c) => c.id == id);
    if (i < 0) throw const PostSubmitException('기록을 찾을 수 없어요');

    final species = SpeciesSeed.all.firstWhere((s) => s.id == draft.speciesId);
    final updated = CatchRecord(
      id: id,
      speciesId: species.id,
      speciesName: species.name,
      // 서버와 같은 순서 규칙 — 남긴 장이 앞, 새로 올린 장이 뒤다.
      // 목에는 사진을 올릴 서버가 없어서 새 장은 URL 이 생기지 않는다.
      photoUrls: keepPhotoUrls,
      lengthCm: draft.lengthCm,
      caughtAt: draft.caughtAt,
      spotName: draft.spotName,
      memo: draft.memo,
    );
    _catches[i] = updated;
    return updated;
  }

  @override
  Future<void> deleteCatch(int id) async {
    await Future.delayed(_latency);
    _catches.removeWhere((c) => c.id == id);
  }

  @override
  Future<List<Spot>> searchSpots(String query) async {
    await Future.delayed(_latency);
    final q = query.trim();
    if (q.isEmpty) return const [];
    return MockData.spots.where((s) => s.name.contains(q)).toList();
  }

  @override
  Future<List<Post>> fetchPosts({
    PostCategory? category,
    int? regionGroupId,
  }) async {
    await Future.delayed(_latency);
    return _posts
        .where((p) => category == null || p.category == category)
        .toList();
  }

  /// 목 저장소의 댓글·좋아요. 서버가 소유하는 것을 여기서는 메모리에 둔다.
  final Map<int, List<Comment>> _comments = {};
  final Set<int> _liked = {};
  final Set<int> _reported = {};
  int _nextCommentId = 1;

  /// 내가 쓴 글. 서버는 `user_id` 로 알지만 목에는 사용자가 없어서 따로 센다 —
  /// 이게 없으면 수정·삭제 버튼이 어디에도 안 뜬다. 시드 글은 여기 없다(남의 글).
  final Set<int> _mine = {};

  @override
  Future<PostDetail> fetchPost(int id) async {
    await Future.delayed(_latency);
    final post = _posts.firstWhere((p) => p.id == id);
    return PostDetail(
      id: post.id,
      category: post.category,
      title: post.title,
      // 목 데이터에는 본문이 따로 없다. 목록 요약을 그대로 쓴다.
      content: post.summary,
      authorNickname: post.authorNickname,
      createdAt: post.createdAt,
      likeCount: post.likeCount + (_liked.contains(id) ? 1 : 0),
      commentCount: _comments[id]?.length ?? post.commentCount,
      likedByMe: _liked.contains(id),
      regionName: post.regionName,
      mine: _mine.contains(id),
    );
  }

  @override
  Future<PostDetail> updatePost({
    required int id,
    required PostCategory category,
    required String title,
    required String content,
    PickedPhoto? photo,
  }) async {
    await Future.delayed(_latency);
    final i = _posts.indexWhere((p) => p.id == id);
    final old = _posts[i];
    _posts[i] = Post(
      id: old.id,
      category: category,
      title: title,
      summary: content,
      authorNickname: old.authorNickname,
      createdAt: old.createdAt,
      likeCount: old.likeCount,
      commentCount: old.commentCount,
      hasImage: photo != null || old.hasImage,
      regionName: old.regionName,
    );
    return fetchPost(id);
  }

  @override
  Future<void> deletePost(int id) async {
    await Future.delayed(_latency);
    _posts.removeWhere((p) => p.id == id);
    // 서버는 ON DELETE CASCADE 로 함께 지운다 (V9).
    _comments.remove(id);
    _liked.remove(id);
    _mine.remove(id);
  }

  @override
  Future<List<Comment>> fetchComments(int postId) async {
    await Future.delayed(_latency);
    return List.unmodifiable(_comments[postId] ?? const []);
  }

  @override
  Future<Comment> createComment(int postId, String content) async {
    await Future.delayed(_latency);
    final comment = Comment(
      id: _nextCommentId++,
      authorNickname: MockData.profile.nickname,
      content: content,
      createdAt: DateTime.now(),
      mine: true,
    );
    (_comments[postId] ??= []).add(comment);
    return comment;
  }

  @override
  Future<void> deleteComment(int commentId) async {
    await Future.delayed(_latency);
    for (final list in _comments.values) {
      list.removeWhere((c) => c.id == commentId);
    }
  }

  @override
  Future<({int likeCount, bool likedByMe})> toggleLike(int postId) async {
    await Future.delayed(_latency);
    final liked = !_liked.contains(postId);
    if (liked) {
      _liked.add(postId);
    } else {
      _liked.remove(postId);
    }
    final base = _posts.firstWhere((p) => p.id == postId).likeCount;
    return (likeCount: base + (liked ? 1 : 0), likedByMe: liked);
  }

  @override
  Future<bool> reportPost(
    int postId, {
    required ReportReason reason,
    String? detail,
  }) async {
    await Future.delayed(_latency);
    // 서버와 같은 규칙 둘 — 내 글은 못 신고하고, 두 번째 신고는 오류가 아니다.
    if (_mine.contains(postId)) {
      throw const PostSubmitException('내가 쓴 글은 신고할 수 없어요');
    }
    return !_reported.add(postId);
  }

  @override
  Future<Post> createPost({
    required PostCategory category,
    required String title,
    required String content,
    PickedPhoto? photo,
  }) async {
    await Future.delayed(_latency);
    final post = Post(
      id: DateTime.now().millisecondsSinceEpoch,
      category: category,
      title: title,
      summary: content,
      authorNickname: MockData.profile.nickname,
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      hasImage: photo != null,
    );
    // 목록 맨 앞에 넣는다 — 서버도 최신순이라 방금 쓴 글이 위에 보여야 한다.
    _posts.insert(0, post);
    _mine.add(post.id);
    return post;
  }

  @override
  Future<Profile?> fetchProfile() async {
    await Future.delayed(_latency);
    return MockData.profile;
  }

  // ── 도감 조립 ───────────────────────────────────────────────

  List<CollectionEntry> _buildCollection() =>
      SpeciesSeed.all.map(_entryFor).toList();

  /// 한 어종의 내 기록을 모아 도감 칸 하나를 만든다.
  ///
  /// ⚠️ 규칙은 서버 `CollectionEntryResponse.of` 와 **같아야 한다** — 다르면
  /// `USE_MOCK` 을 끄는 순간 표지와 최고 기록이 바뀐다.
  CollectionEntry _entryFor(Species species) {
    final mine = _catches.where((c) => c.speciesId == species.id).toList();
    if (mine.isEmpty) return CollectionEntry(species: species);

    // 길이는 선택이라 null 이 섞인다 — 없는 것은 가장 작은 것으로 본다 (서버와 같은 규칙).
    mine.sort((a, b) => (b.lengthCm ?? -1).compareTo(a.lengthCm ?? -1));
    final best = mine.first;
    final first = mine.map((c) => c.caughtAt).reduce((a, b) => a.isBefore(b) ? a : b);

    // 표지도 가장 큰 개체의 것이지만, 그 기록에 사진이 없을 수 있다 —
    // **사진이 있는 것 중** 가장 큰 것을 고른다. 칸이 비는 것보다 낫다.
    final cover = mine
        .map((c) => c.coverPhotoUrl)
        .firstWhere((url) => url != null && url.isNotEmpty, orElse: () => null);

    return CollectionEntry(
      species: species,
      catchCount: mine.length,
      bestLengthCm: best.lengthCm,
      coverPhotoUrl: cover,
      firstCaughtAt: first,
    );
  }
}
