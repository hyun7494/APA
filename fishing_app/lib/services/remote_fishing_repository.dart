import 'package:dio/dio.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'fishing_repository.dart';
import 'photo_picker.dart';

/// 실제 app-fishing(:8086, `/fishing/**`) 호출 구현.
///
/// 기본 실행에서는 아직 [MockFishingRepository]가 쓰인다.
/// 전환은 `--dart-define=USE_MOCK=false`.
///
/// ## 비로그인 도감
///
/// 서버의 도감·조과 API는 전부 `/fishing/me/**` 아래라 비로그인이면 401이다.
/// 그런데 **도감 탭 자체는 로그인 없이 열려야 한다** (기획서 5-5) — 전 칸이 잠긴
/// 마스터 도감을 보여주고 조과 등록을 누를 때만 로그인을 요구한다.
///
/// 그래서 도감 관련 호출은 401을 예외로 올리지 않고 **어종 마스터
/// (`GET /fishing/species`, 비로그인 OK)로 갈아타** 잠긴 칸을 만든다.
/// 로그인 화면이 붙기 전까지는 모든 사용자가 이 경로를 탄다.
class RemoteFishingRepository implements FishingRepository {
  RemoteFishingRepository(this._client);

  final ApiClient _client;

  Dio get _dio => _client.dio;

  @override
  Future<List<RegionGroup>> fetchRegions() async {
    final res = await _dio.get<List<dynamic>>('/fishing/regions');
    return _mapList(res.data, RegionGroup.fromJson);
  }

  @override
  Future<List<RegionGroup>> searchRegions(String query) async {
    final res = await _dio.get<List<dynamic>>(
      '/fishing/regions/search',
      queryParameters: {'q': query},
    );
    return _mapList(res.data, RegionGroup.fromJson);
  }

  @override
  Future<List<Spot>> fetchSpots(int regionGroupId) async {
    final res = await _dio.get<List<dynamic>>(
      '/fishing/spots',
      queryParameters: {'regionGroupId': regionGroupId},
    );
    return _mapList(res.data, Spot.fromJson);
  }

  @override
  Future<Spot> fetchSpot(int id) async {
    final res = await _dio.get<Map<String, dynamic>>('/fishing/spots/$id');
    return Spot.fromJson(res.data!);
  }

  @override
  Future<List<CollectionEntry>> fetchCollection() async {
    try {
      final res = await _dio.get<List<dynamic>>('/fishing/me/collection');
      return _mapList(res.data, CollectionEntry.fromJson);
    } on DioException catch (e) {
      if (!_isUnauthorized(e)) rethrow;
      // 비로그인 — 마스터 도감을 전 칸 잠금으로 그린다.
      final res = await _dio.get<List<dynamic>>('/fishing/species');
      return _mapList(res.data, Species.fromJson)
          .map((s) => CollectionEntry(species: s))
          .toList();
    }
  }

  @override
  Future<CollectionEntry> fetchCollectionEntry(int speciesId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/fishing/me/collection/$speciesId',
      );
      return CollectionEntry.fromJson(res.data!);
    } on DioException catch (e) {
      if (!_isUnauthorized(e)) rethrow;
      final res = await _dio.get<Map<String, dynamic>>(
        '/fishing/species/$speciesId',
      );
      return CollectionEntry(species: Species.fromJson(res.data!));
    }
  }

  @override
  Future<List<CatchRecord>> fetchCatches({int? speciesId}) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/fishing/me/catches',
        queryParameters: {'speciesId': ?speciesId},
      );
      return _mapList(res.data, CatchRecord.fromJson);
    } on DioException catch (e) {
      // 비로그인은 기록이 없는 것과 같다. 여기서 예외를 올리면 어종 상세 화면이
      // 통째로 에러 뷰가 되는데, 도감 정보는 비로그인도 볼 수 있어야 한다.
      if (!_isUnauthorized(e)) rethrow;
      return const [];
    }
  }

  @override
  Future<CatchResult> registerCatch(CatchDraft draft) async {
    // 사진은 여러 장이고 순서가 그대로 간다 — 첫 장이 도감 칸의 표지가 된다.
    // 같은 이름(`photos`)의 파트를 여러 번 보내면 서버가 List 로 받는다.
    final form = FormData();
    form.fields.addAll([
      MapEntry('speciesId', '${draft.speciesId}'),
      MapEntry('caughtAt', draft.caughtAt.toIso8601String()),
      // 길이는 선택이다 (V11). null 이면 필드를 아예 안 보낸다 —
      // 빈 문자열을 보내면 서버가 숫자로 못 읽어 400 이 된다.
      if (draft.lengthCm != null) MapEntry('lengthCm', '${draft.lengthCm}'),
      if (draft.spotName.isNotEmpty) MapEntry('spotName', draft.spotName),
      if (draft.memo.isNotEmpty) MapEntry('memo', draft.memo),
    ]);
    form.files.addAll(_photoParts(draft.photos));

    final res = await _dio.post<Map<String, dynamic>>(
      '/fishing/me/catches',
      data: form,
    );
    return CatchResult.fromJson(res.data!);
  }

  @override
  Future<CatchRecord> updateCatch(
    int id,
    CatchDraft draft, {
    required List<String> keepPhotoUrls,
  }) async {
    final form = FormData();
    form.fields.addAll([
      MapEntry('speciesId', '${draft.speciesId}'),
      MapEntry('caughtAt', draft.caughtAt.toIso8601String()),
      if (draft.lengthCm != null) MapEntry('lengthCm', '${draft.lengthCm}'),
      // 등록과 달리 **빈 값도 보낸다.** 여기서 생략하면 서버가 "지운 게 아니라
      // 안 건드린 것" 으로 읽어서, 지운 메모·포인트가 되살아난다.
      MapEntry('spotName', draft.spotName),
      MapEntry('memo', draft.memo),
      // 남길 장. 파트를 여러 번 보낸다 — 순서가 그대로 저장된다.
      //
      // ⚠️ 한 장도 안 남길 때도 **빈 값으로 한 번은 보내야 한다.** 아예 안 보내면
      //    서버는 "사진을 건드리지 말라" 로 읽어서 뗀 사진이 그대로 남는다.
      if (keepPhotoUrls.isEmpty)
        const MapEntry('keepPhotoUrls', '')
      else
        for (final url in keepPhotoUrls) MapEntry('keepPhotoUrls', url),
    ]);
    form.files.addAll(_photoParts(draft.photos));

    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/fishing/me/catches/$id',
        data: form,
      );
      return CatchRecord.fromJson(res.data!);
    } on DioException catch (e) {
      throw PostSubmitException(_submitMessage(e, '기록을 고치지 못했어요'));
    }
  }

  /// 조과 사진 파트. 같은 이름(`photos`)을 여러 번 보내면 서버가 List 로 받고,
  /// **보낸 순서가 그대로 저장된다** — 첫 장이 도감 칸의 표지가 된다.
  ///
  /// 서버(`PhotoStorageService`)는 **선언된 Content-Type 으로만** 형식을 판정한다.
  /// Dio 는 보통 파일명 확장자를 보고 채워 주지만, 확장자가 없으면
  /// application/octet-stream 으로 떨어져서 멀쩡한 JPEG 도 "JPEG 또는 PNG 사진만"
  /// 400 이 된다. 카메라가 만든 임시 파일명에는 확장자가 없을 수 있어 추측에 맡기지 않는다.
  static List<MapEntry<String, MultipartFile>> _photoParts(
    List<PickedPhoto> photos,
  ) => [
    for (final photo in photos)
      MapEntry(
        'photos',
        MultipartFile.fromBytes(
          photo.bytes,
          filename: photo.name,
          contentType: DioMediaType.parse(photo.mimeType),
        ),
      ),
  ];

  @override
  Future<void> deleteCatch(int id) async {
    await _dio.delete<void>('/fishing/me/catches/$id');
  }

  @override
  Future<List<Post>> fetchPosts({
    PostCategory? category,
    int? regionGroupId,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/fishing/board',
      queryParameters: {
        'tag': ?category?.code,
        'regionGroupId': ?regionGroupId,
      },
    );
    return _mapList(res.data, Post.fromJson);
  }

  @override
  Future<PostDetail> fetchPost(int id) async {
    final res = await _dio.get<Map<String, dynamic>>('/fishing/board/$id');
    return PostDetail.fromJson(res.data!);
  }

  @override
  Future<PostDetail> updatePost({
    required int id,
    required PostCategory category,
    required String title,
    required String content,
    PickedPhoto? photo,
  }) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/fishing/board/$id',
        data: _postForm(category, title, content, photo),
      );
      return PostDetail.fromJson(res.data!);
    } on DioException catch (e) {
      throw PostSubmitException(_submitMessage(e, '글을 고치지 못했어요'));
    }
  }

  @override
  Future<void> deletePost(int id) async {
    try {
      await _dio.delete<void>('/fishing/board/$id');
    } on DioException catch (e) {
      throw PostSubmitException(_submitMessage(e, '글을 지우지 못했어요'));
    }
  }

  @override
  Future<List<Comment>> fetchComments(int postId) async {
    final res = await _dio.get<List<dynamic>>('/fishing/board/$postId/comments');
    return _mapList(res.data, Comment.fromJson);
  }

  @override
  Future<Comment> createComment(int postId, String content) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/fishing/board/$postId/comments',
        data: {'content': content},
      );
      return Comment.fromJson(res.data!);
    } on DioException catch (e) {
      throw PostSubmitException(_submitMessage(e, '댓글을 남기지 못했어요'));
    }
  }

  @override
  Future<void> deleteComment(int commentId) async {
    try {
      await _dio.delete<void>('/fishing/board/comments/$commentId');
    } on DioException catch (e) {
      throw PostSubmitException(_submitMessage(e, '댓글을 지우지 못했어요'));
    }
  }

  @override
  Future<bool> reportPost(
    int postId, {
    required ReportReason reason,
    String? detail,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/fishing/board/$postId/report',
        data: {'reason': reason.code, 'detail': ?detail},
      );
      return res.data?['alreadyReported'] as bool? ?? false;
    } on DioException catch (e) {
      throw PostSubmitException(_submitMessage(e, '신고를 접수하지 못했어요'));
    }
  }

  @override
  Future<({int likeCount, bool likedByMe})> toggleLike(int postId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/fishing/board/$postId/like',
      );
      final data = res.data!;
      return (
        likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
        likedByMe: data['likedByMe'] as bool? ?? false,
      );
    } on DioException catch (e) {
      throw PostSubmitException(_submitMessage(e, '좋아요를 반영하지 못했어요'));
    }
  }

  /// 글쓰기·고치기가 같은 폼을 보낸다.
  ///
  /// 사진이 붙으면서 JSON 이 아니라 multipart 가 됐다 — 조과 등록과 같은 모양이다.
  /// **사진이 없으면 파트를 아예 넣지 않는다.** 고치기에서 빈 파트를 보내면 서버가
  /// "사진을 뗐다"로 읽을 여지가 생긴다.
  FormData _postForm(
    PostCategory category,
    String title,
    String content,
    PickedPhoto? photo,
  ) => FormData.fromMap({
    'category': category.code,
    'title': title,
    'content': content,
    if (photo != null)
      'photo': MultipartFile.fromBytes(
        photo.bytes,
        filename: photo.name,
        // 서버는 선언된 Content-Type 으로만 형식을 판정한다 (registerCatch 주석 참고).
        contentType: DioMediaType.parse(photo.mimeType),
      ),
  });

  @override
  Future<Post> createPost({
    required PostCategory category,
    required String title,
    required String content,
    PickedPhoto? photo,
  }) async {
    // 작성자(user_id·닉네임)는 보내지 않는다. 서버가 토큰에서 가져간다 —
    // 본문으로 받으면 아무나 남의 이름으로 쓸 수 있다.
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/fishing/board',
        data: _postForm(category, title, content, photo),
      );
      return Post.fromJson(res.data!);
    } on DioException catch (e) {
      throw PostSubmitException(_submitMessage(e, '글을 올리지 못했어요'));
    }
  }

  @override
  Future<Profile?> fetchProfile() async {
    if (!await _client.isLoggedIn) return null;
    try {
      final res = await _dio.get<Map<String, dynamic>>('/fishing/me/profile');
      return Profile.fromJson(res.data!);
    } on DioException catch (e) {
      // 비로그인 우선 원칙 — 인증 실패는 예외 대신 "로그인 안 됨"으로 다룬다.
      if (e.response?.statusCode == 401) return null;
      rethrow;
    }
  }

  /// 쓰기 실패를 화면에 띄울 한 줄로 바꾼다.
  ///
  /// 서버가 문구를 주면 그대로 쓴다 — "제목을 입력해 주세요"가 "실패했어요"보다 언제나 낫다.
  String _submitMessage(DioException e, String fallback) {
    if (_isUnauthorized(e)) {
      // 관문을 통과해 들어왔는데 여기서 401 이면 그 사이 토큰이 만료된 것이다.
      return '로그인이 만료되었어요. 다시 로그인해 주세요';
    }
    return _serverDetail(e) ?? '$fallback. 잠시 후 다시 시도해 주세요';
  }

  /// 서버는 오류를 ProblemDetail(JSON) 로 내려준다.
  static String? _serverDetail(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] is String) return data['detail'] as String;
    if (data is String && data.isNotEmpty) return data;
    return null;
  }

  /// 인증 실패는 "로그인 안 됨"이지 오류가 아니다. [ApiClient]의 인터셉터가 refresh를
  /// 먼저 시도하므로, 여기까지 401이 올라왔다는 건 갱신할 토큰도 없다는 뜻이다.
  static bool _isUnauthorized(DioException e) => e.response?.statusCode == 401;

  static List<T> _mapList<T>(
    List<dynamic>? data,
    T Function(Map<String, dynamic>) fromJson,
  ) =>
      (data ?? const [])
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
}
