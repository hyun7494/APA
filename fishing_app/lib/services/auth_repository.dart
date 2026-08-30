import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'social_sign_in.dart';

/// 로그인한 사용자. 서버 `TokenResponse.user` 와 같은 모양이다.
@immutable
/// 동의 한 건. 서버 `ConsentRequest` 와 모양이 같다.
///
/// ⚠️ [version] 은 **사용자가 실제로 본 문서의 판**이다. 앱이 화면에 띄운 그 값을
/// 그대로 보낸다 — 서버가 지어내면 "그때 뭐에 동의한 거냐" 에 답할 수 없다.
class ConsentAnswer {
  const ConsentAnswer({
    required this.type,
    required this.version,
    required this.agreed,
  });

  final String type;
  final String version;
  final bool agreed;

  Map<String, dynamic> toJson() => {
    'type': type,
    'version': version,
    'agreed': agreed,
  };
}

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

/// 소셜 신원은 확인됐는데 **같은 이메일로 자체 가입한 계정이 이미 있는** 경우
/// (서버 409 `LINK_REQUIRED`).
///
/// 실패가 아니라 **한 단계 더 필요한 상태**다. 비밀번호를 받아 [AuthRepository.linkSocial]
/// 로 넘기면 두 신원이 한 계정으로 합쳐지고 그대로 로그인된다. 여기서 새 계정을 만들어
/// 버리면 도감·조과가 둘로 쪼개진다.
@immutable
class SocialLinkRequired implements Exception {
  const SocialLinkRequired({
    required this.provider,
    required this.token,
    required this.email,
  });

  final SocialProvider provider;

  /// 방금 받은 소셜 토큰. **연동 확인 요청에 그대로 다시 실어 보낸다** —
  /// 서버가 한 번 더 검증하므로 우리가 결과를 들고 있을 필요가 없다.
  final String token;

  /// 이미 가입돼 있는 주소. 화면에 보여 줘야 사용자가 어느 비밀번호인지 안다.
  final String email;
}

/// 인증 계약. 구현은 [RemoteAuthRepository] 하나이고, 인터페이스인 이유는 테스트다 —
/// 위젯 테스트가 진짜 auth-service 와 제공자 SDK 를 부를 수는 없다.
abstract interface class AuthRepository {
  /// @throws [SocialLinkRequired] 같은 이메일의 자체 가입 계정이 이미 있을 때
  Future<AuthUser> signIn(SocialProvider provider);

  /// 자체 회원가입. 가입과 동시에 로그인 상태가 된다.
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String nickname,
    /// 약관 동의. 서버가 **필수 항목이 빠지면 400** 이다 — 화면에서 막는 것과 별개로
    /// 서버가 마지막 방어선이라, 여기서 안 보내면 가입이 안 된다.
    required List<ConsentAnswer> consents,
  });

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  });

  /// 계정 연동 — [SocialLinkRequired] 를 비밀번호로 풀고 그대로 로그인한다.
  Future<AuthUser> linkSocial(SocialLinkRequired link, String password);

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

    return _exchange('/auth/login', {
      'provider': credential.provider.code,
      'token': credential.token,
      'appId': appId,
      // 409 LINK_REQUIRED 는 실패가 아니라 "비밀번호를 한 번 더 받아라"는 신호다.
      // 토큰은 여기서만 알 수 있으므로 예외에 실어 올려보낸다.
    }, onLinkRequired: (email) => SocialLinkRequired(
      provider: credential.provider,
      token: credential.token,
      email: email,
    ));
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String nickname,
    required List<ConsentAnswer> consents,
  }) => _exchange('/auth/signup', {
    'email': email,
    'password': password,
    'nickname': nickname,
    'appId': appId,
    'consents': [for (final c in consents) c.toJson()],
  });

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) => _exchange('/auth/login/email', {
    'email': email,
    'password': password,
    'appId': appId,
  });

  @override
  Future<AuthUser> linkSocial(SocialLinkRequired link, String password) =>
      _exchange('/auth/link/social', {
        'provider': link.provider.code,
        // 같은 소셜 토큰을 다시 보낸다. 서버가 한 번 더 검증한다.
        'token': link.token,
        'password': password,
        'appId': appId,
      });

  /// 네 경로가 모두 같은 `TokenResponse` 를 돌려준다 — 교환·저장을 한 자리에 모은다.
  ///
  /// [onLinkRequired] 는 소셜 로그인만 넘긴다. 다른 경로에서는 서버가 409
  /// `LINK_REQUIRED` 를 낼 일이 없다.
  Future<AuthUser> _exchange(
    String path,
    Map<String, dynamic> body, {
    SocialLinkRequired Function(String email)? onLinkRequired,
  }) async {
    final Response<Map<String, dynamic>> res;
    try {
      res = await _dio.post<Map<String, dynamic>>(path, data: body);
    } on DioException catch (e) {
      final link = _linkRequired(e, onLinkRequired);
      if (link != null) throw link;
      throw _toAuthException(e);
    }

    final data = res.data!;
    await _client.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// 문구가 아니라 `code` 로 알아본다. 서버 문구는 언제든 다듬을 수 있어야 한다.
  SocialLinkRequired? _linkRequired(
    DioException e,
    SocialLinkRequired Function(String email)? build,
  ) {
    if (build == null || e.response?.statusCode != 409) return null;
    final data = e.response?.data;
    if (data is! Map || data['code'] != 'LINK_REQUIRED') return null;
    final email = data['email'];
    return build(email is String ? email : '');
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
    // 400(형식 오류)·409(중복 가입)·401 은 모두 사용자에게 보여 줄 문구가 서버에 있다.
    // "이미 가입된 이메일입니다"를 "로그인에 실패했습니다"로 덮으면 무엇을 고쳐야 할지
    // 알 수 없어진다.
    if (status == 400 || status == 401 || status == 409) {
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
