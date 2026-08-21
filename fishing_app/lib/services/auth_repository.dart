import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'social_sign_in.dart';

/// 로그인한 사용자. 서버 `TokenResponse.user` 와 같은 모양이다.
@immutable
class AuthUser {
  const AuthUser({required this.id, required this.nickname, this.profileUrl});

  final int id;
  final String nickname;
  final String? profileUrl;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: (json['id'] as num).toInt(),
    nickname: json['nickname'] as String? ?? '',
    profileUrl: json['profileUrl'] as String?,
  );
}

/// 로그인이 실패했을 때 화면에 그대로 띄울 수 있는 메시지.
class AuthException implements Exception {
  const AuthException(this.message, {this.providerUnavailable = false});

  final String message;

  /// 제공자(카카오·구글) 쪽 장애. **사용자가 고칠 수 있는 문제가 아니다.**
  final bool providerUnavailable;

  @override
  String toString() => message;
}

/// 인증 계약. 구현은 [RemoteAuthRepository] 하나이고, 인터페이스인 이유는 테스트다 —
/// 위젯 테스트가 진짜 auth-service 와 제공자 SDK 를 부를 수는 없다.
abstract interface class AuthRepository {
  Future<AuthUser> signIn(SocialProvider provider);

  Future<void> signOut();

  Future<bool> get isLoggedIn;
}

/// `auth-service` 호출 + 토큰 보관.
///
/// ⚠️ **auth-service 는 app-fishing 과 다른 포트다** (`:8081` vs `:8086`).
/// 게이트웨이가 생기기 전까지는 두 주소를 따로 들고 있어야 한다 — 하나로 합쳐 두면
/// 로그인만 404 가 나는데, 증상이 "로그인 안 됨"이라 원인을 찾는 데 한참 걸린다.
class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({
    required ApiClient client,
    required SocialSignIn socialSignIn,
  }) : this._(client, socialSignIn);

  RemoteAuthRepository._(this._client, this._socialSignIn)
    : _dio = Dio(
        BaseOptions(
          baseUrl: authBaseUrl.replaceAll(RegExp(r'/+$'), ''),
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

  final ApiClient _client;
  final SocialSignIn _socialSignIn;
  final Dio _dio;

  /// 제공자 로그인 → 서버 토큰 교환 → 저장.
  ///
  /// 사용자가 창을 닫으면 [SignInCancelled] 가 그대로 올라간다. 호출부는 그걸
  /// **아무 일도 없던 것처럼** 다뤄야 한다 — 취소는 실패가 아니다.
  @override
  Future<AuthUser> signIn(SocialProvider provider) async {
    final credential = await _socialSignIn.signIn(provider);

    final Response<Map<String, dynamic>> res;
    try {
      res = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'provider': credential.provider.code,
          'token': credential.token,
          'appId': appId,
        },
      );
    } on DioException catch (e) {
      throw _toAuthException(e);
    }

    final data = res.data!;
    await _client.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// 서버의 리프레시 토큰을 버리고 제공자 세션도 끊는다.
  ///
  /// **로컬 토큰은 서버 호출이 실패해도 반드시 지운다.** 서버가 죽었다고 로그아웃이
  /// 안 되면 사용자는 자기 기기에서 계정을 뺄 방법이 없다.
  @override
  Future<void> signOut() async {
    try {
      final token = await _client.accessToken;
      if (token != null) {
        await _dio.post<void>(
          '/auth/logout',
          queryParameters: {'appId': appId},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      }
    } catch (_) {
      // 서버에 못 알려도 계속 진행한다. 액세스 토큰은 1시간이면 어차피 만료된다.
    }
    try {
      await _socialSignIn.signOut();
    } catch (_) {
      // 제공자 세션 해제 실패도 로그아웃을 막을 이유는 못 된다.
    }
    await _client.clearTokens();
  }

  @override
  Future<bool> get isLoggedIn => _client.isLoggedIn;

  AuthException _toAuthException(DioException e) {
    final status = e.response?.statusCode;
    if (status == 503) {
      return const AuthException(
        '로그인 서비스가 일시적으로 불안정합니다. 잠시 후 다시 시도해 주세요',
        providerUnavailable: true,
      );
    }
    if (status == 401) {
      // 서버가 문구를 내려주면 그대로 쓴다 — "만료됐다"와 "탈퇴한 계정"은 다른 안내다.
      return AuthException(_serverMessage(e) ?? '로그인에 실패했습니다. 다시 시도해 주세요');
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const AuthException('서버에 연결하지 못했습니다. 네트워크를 확인해 주세요');
    }
    return AuthException(_serverMessage(e) ?? '로그인에 실패했습니다');
  }

  /// 서버는 문자열(UnauthorizedException) 또는 ProblemDetail(JSON) 로 내려준다.
  String? _serverMessage(DioException e) {
    final data = e.response?.data;
    if (data is String && data.isNotEmpty) return data;
    if (data is Map && data['detail'] is String) return data['detail'] as String;
    return null;
  }
}

/// auth-service 주소.
///
/// 안드로이드 에뮬레이터에서 호스트 PC 는 `10.0.2.2` 다 (localhost 아님).
const authBaseUrl = String.fromEnvironment(
  'AUTH_BASE_URL',
  defaultValue: 'http://10.0.2.2:8081',
);
