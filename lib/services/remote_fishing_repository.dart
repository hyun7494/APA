import 'package:dio/dio.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'fishing_repository.dart';

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
    // 사진이 필수라 multipart로 보낸다 (기획서 4-3 이미지 저장 설계).
    final form = FormData.fromMap({
      'speciesId': draft.speciesId,
      'lengthCm': draft.lengthCm,
      'caughtAt': draft.caughtAt.toIso8601String(),
      if (draft.spotName.isNotEmpty) 'spotName': draft.spotName,
      if (draft.memo.isNotEmpty) 'memo': draft.memo,
      if (draft.photoPath.isNotEmpty)
        'photo': await MultipartFile.fromFile(draft.photoPath),
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '/fishing/me/catches',
      data: form,
    );
    return CatchResult.fromJson(res.data!);
  }

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
