import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// APA 게이트웨이 주소. 빌드 시 덮어쓴다:
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8086`
///
/// 안드로이드 에뮬레이터에서 호스트 PC는 10.0.2.2 다 (localhost 아님).
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8086',
);

/// 소셜 로그인 시 auth-service에 넘길 앱 식별자 (기획서 0장).
const appId = 'FISHING';

/// JWT를 자동으로 붙이고 401이면 refresh를 시도하는 dio 인스턴스.
/// (기획서 5-3)
class ApiClient {
  ApiClient({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage() {
    dio = Dio(
      BaseOptions(
        // 끝 슬래시를 떼고 쓴다. `http://localhost:8086/` 처럼 넘어오면 dio가 경로를
        // 이어붙여 `//fishing/regions`를 보내는데, Spring Security의 StrictHttpFirewall이
        // 필터 체인 맨 앞에서 400으로 끊는다. CORS 헤더를 붙이는 필터까지 못 가므로
        // 브라우저에는 "blocked by CORS policy"로 뜬다 — 증상과 원인이 완전히 다르다.
        baseUrl: apiBaseUrl.replaceAll(RegExp(r'/+$'), ''),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: _attachToken, onError: _refreshOn401),
    );
  }

  static const _accessTokenKey = 'apa.accessToken';
  static const _refreshTokenKey = 'apa.refreshToken';

  final FlutterSecureStorage _storage;
  late final Dio dio;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<bool> get isLoggedIn async =>
      await _storage.read(key: _accessTokenKey) != null;

  Future<void> _attachToken(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  /// 401이면 `/auth/refresh`로 재발급 후 원 요청을 한 번만 재시도한다.
  Future<void> _refreshOn401(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['retried'] == true;
    if (!isUnauthorized || alreadyRetried) {
      return handler.next(err);
    }

    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) return handler.next(err);

    try {
      // refresh 요청 자체는 인터셉터를 타지 않는 별도 Dio로 보낸다.
      final res = await Dio(BaseOptions(baseUrl: apiBaseUrl)).post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = res.data!;
      await saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String? ?? refreshToken,
      );

      final retry = err.requestOptions..extra['retried'] = true;
      handler.resolve(await dio.fetch(retry));
    } on DioException {
      await clearTokens();
      handler.next(err);
    }
  }
}
