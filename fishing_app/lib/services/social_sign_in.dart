import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

/// 로그인 제공자. 서버 `SocialType` 과 이름이 같아야 한다.
enum SocialProvider {
  kakao('KAKAO', '카카오로 시작하기'),
  google('GOOGLE', 'Google로 시작하기');

  const SocialProvider(this.code, this.label);

  /// `POST /auth/login` 의 `provider` 로 그대로 나간다.
  final String code;

  final String label;
}

/// 제공자에게서 받은 토큰. 이걸 서버로 넘기면 서버가 제공자에게 되물어 신원을 확인한다.
///
/// **제공자마다 넘기는 토큰의 종류가 다르다** — 카카오는 액세스 토큰, 구글은 ID 토큰이다.
/// 구글에 액세스 토큰을 보내면 `tokeninfo` 가 400 을 낸다.
@immutable
class SocialCredential {
  const SocialCredential({required this.provider, required this.token});

  final SocialProvider provider;
  final String token;
}

/// 사용자가 로그인 창을 닫았을 때. 오류가 아니므로 화면에 빨간 문구를 띄우면 안 된다.
class SignInCancelled implements Exception {
  const SignInCancelled();
}

/// 제공자 SDK 를 부르는 자리.
///
/// 인터페이스로 둔 이유는 사진 선택기와 같다 — 위젯 테스트에서 플랫폼 채널을 부르면
/// 응답이 오지 않아 로그인 이후 흐름을 전혀 검증할 수 없다.
abstract interface class SocialSignIn {
  /// @throws [SignInCancelled] 사용자가 취소한 경우
  Future<SocialCredential> signIn(SocialProvider provider);

  /// 제공자 쪽 세션도 끊는다. 이걸 안 하면 "로그아웃 후 다시 로그인"이 계정 선택 없이
  /// 곧바로 같은 계정으로 들어가서, 계정을 바꿀 방법이 없어진다.
  Future<void> signOut();
}

/// 실제 SDK 구현.
class PlatformSocialSignIn implements SocialSignIn {
  PlatformSocialSignIn();

  @override
  Future<SocialCredential> signIn(SocialProvider provider) async => switch (provider) {
    SocialProvider.kakao => SocialCredential(
      provider: provider,
      token: await _kakaoToken(),
    ),
    SocialProvider.google => SocialCredential(
      provider: provider,
      token: await _googleIdToken(),
    ),
  };

  /// 카카오톡이 깔려 있으면 앱으로, 아니면 웹으로 넘긴다.
  ///
  /// 카카오톡이 있는데도 앱 로그인이 실패하는 경우가 있다 — 사용자가 앱 전환 화면에서
  /// 뒤로 가거나, 카카오톡 계정이 로그아웃 상태일 때다. **그때 웹으로 다시 시도하지 않으면
  /// 로그인이 그냥 실패한 것처럼 보인다.**
  Future<String> _kakaoToken() async {
    OAuthToken token;
    if (await isKakaoTalkInstalled()) {
      try {
        token = await UserApi.instance.loginWithKakaoTalk();
      } on PlatformException catch (e) {
        // 사용자가 카카오톡 화면에서 취소한 것은 웹으로 재시도할 일이 아니다.
        if (e.code == 'CANCELED') throw const SignInCancelled();
        token = await UserApi.instance.loginWithKakaoAccount();
      } catch (_) {
        token = await UserApi.instance.loginWithKakaoAccount();
      }
    } else {
      token = await UserApi.instance.loginWithKakaoAccount();
    }
    return token.accessToken;
  }

  /// **ID 토큰을 꺼낸다.** 서버가 `tokeninfo` 로 검증하는 대상이 그것이다.
  Future<String> _googleIdToken() async {
    final signIn = GoogleSignIn.instance;
    await signIn.initialize(serverClientId: googleServerClientId.isEmpty
        ? null
        : googleServerClientId);

    final GoogleSignInAccount account;
    try {
      account = await signIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SignInCancelled();
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      // serverClientId 를 안 넘기면 안드로이드에서 idToken 이 null 로 온다.
      // 증상이 "로그인은 됐는데 서버가 거절"이라 원인을 찾기 어렵다.
      throw StateError(
        'Google ID 토큰이 비어 있습니다. GOOGLE_SERVER_CLIENT_ID 를 넣었는지 확인하세요',
      );
    }
    return idToken;
  }

  @override
  Future<void> signOut() async {
    // 한쪽이 실패해도 다른 쪽은 끊는다. 어차피 로컬 토큰은 지우고 나갈 것이다.
    try {
      await UserApi.instance.logout();
    } catch (_) {
      // 카카오로 로그인한 적이 없으면 여기서 던진다. 정상이다.
    }
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // 마찬가지.
    }
  }
}

/// 카카오 네이티브 앱 키 (developers.kakao.com → 내 애플리케이션 → 앱 키).
///
/// **비밀값이 아니다** — 앱 번들에 그대로 들어가고 안드로이드 매니페스트에도 적힌다.
/// 그래도 저장소에 박지 않는 이유는 환경(개발/운영)마다 앱이 다르기 때문이다.
const kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');

/// 카카오 JavaScript 키. 웹(`flutter run -d chrome`)에서만 쓴다.
const kakaoJavaScriptKey = String.fromEnvironment('KAKAO_JS_KEY');

/// 구글 **웹** 클라이언트 ID.
///
/// 안드로이드에서 ID 토큰을 받으려면 안드로이드 클라이언트 ID 가 아니라 이 값을 넘겨야 하고,
/// 서버 `social.google-audiences` 에 들어가는 `aud` 도 이 값이다. 헷갈리기 쉬운 지점이다.
const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
