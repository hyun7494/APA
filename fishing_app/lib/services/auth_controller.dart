import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'providers.dart';
import 'social_sign_in.dart';

/// 로그인 상태.
///
/// `AsyncValue` 를 안 쓰는 이유: 로그인 실패는 "화면이 에러가 됨"이 아니라 **머무른 채
/// 안내 문구만 뜨는 것**이다. 실패해도 버튼은 계속 눌러야 한다.
@immutable
class AuthState {
  const AuthState({
    this.user,
    this.pending,
    this.emailBusy = false,
    this.error,
    this.linkRequest,
  });

  final AuthUser? user;

  /// 진행 중인 소셜 제공자. null 이면 소셜 쪽은 대기 상태다.
  final SocialProvider? pending;

  /// 이메일 로그인·회원가입이 진행 중인가.
  ///
  /// [pending] 과 따로 두는 이유는 **어느 버튼에 스피너를 돌릴지**가 다르기 때문이다.
  /// 하나로 합치면 이메일 로그인 중에 카카오 버튼이 도는 것처럼 보인다.
  final bool emailBusy;

  final AuthException? error;

  /// 소셜로 들어왔는데 같은 이메일의 자체 가입 계정이 이미 있어서, 비밀번호 확인을
  /// 기다리는 상태. 화면이 이 값을 보고 연동 안내를 띄운다.
  final SocialLinkRequired? linkRequest;

  bool get isLoggedIn => user != null;

  /// 진행 중에는 화면의 모든 입력을 막는다. 카카오 창이 뜬 사이에 이메일 로그인을
  /// 누르면 두 로그인이 겹쳐 어느 쪽 결과가 남을지 알 수 없다.
  bool get isBusy => pending != null || emailBusy;

  AuthState copyWith({
    AuthUser? user,
    SocialProvider? pending,
    bool? emailBusy,
    AuthException? error,
    SocialLinkRequired? linkRequest,
    bool clearUser = false,
    bool clearPending = false,
    bool clearError = false,
    bool clearLinkRequest = false,
  }) => AuthState(
    user: clearUser ? null : (user ?? this.user),
    pending: clearPending ? null : (pending ?? this.pending),
    emailBusy: emailBusy ?? this.emailBusy,
    error: clearError ? null : (error ?? this.error),
    linkRequest: clearLinkRequest ? null : (linkRequest ?? this.linkRequest),
  );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState()) {
    _restore();
  }

  final AuthRepository _repository;

  /// 저장된 토큰이 있으면 로그인 상태로 시작한다.
  ///
  /// 서버에 물어 확인하지는 않는다 — 앱을 켤 때마다 왕복하면 시작이 느려지고, 토큰이
  /// 실제로 죽었다면 첫 API 호출의 401 이 refresh 인터셉터를 태워 알아서 정리된다.
  Future<void> _restore() async {
    if (!await _repository.isLoggedIn) return;
    if (!mounted) return;
    // 닉네임은 아직 모른다. 프로필 화면이 /fishing/me/profile 로 채운다.
    state = state.copyWith(user: const AuthUser(id: 0, nickname: ''));
  }

  /// 소셜 로그인.
  ///
  /// 연동이 필요하면 false 를 돌려주고 [AuthState.linkRequest] 를 채운다 — 화면이
  /// 그걸 보고 비밀번호를 물은 뒤 [confirmLink] 로 잇는다.
  Future<bool> signIn(SocialProvider provider) async {
    if (state.isBusy) return false;
    state = state.copyWith(
      pending: provider,
      clearError: true,
      clearLinkRequest: true,
    );

    return _run(() => _repository.signIn(provider));
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (state.isBusy) return false;
    state = state.copyWith(
      emailBusy: true,
      clearError: true,
      clearLinkRequest: true,
    );

    return _run(() => _repository.signInWithEmail(
      email: email,
      password: password,
    ));
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    if (state.isBusy) return false;
    state = state.copyWith(
      emailBusy: true,
      clearError: true,
      clearLinkRequest: true,
    );

    return _run(() => _repository.signUp(
      email: email,
      password: password,
      nickname: nickname,
    ));
  }

  /// 계정 연동 확인 — 기존 계정의 비밀번호로 소셜을 붙이고 그대로 로그인한다.
  Future<bool> confirmLink(String password) async {
    final link = state.linkRequest;
    if (link == null || state.isBusy) return false;
    state = state.copyWith(emailBusy: true, clearError: true);

    final ok = await _run(() => _repository.linkSocial(link, password));
    // 실패해도 요청 자체는 살려 둔다. 비밀번호를 잘못 친 것뿐일 수 있고,
    // 여기서 지우면 소셜 로그인부터 다시 해야 한다.
    return ok;
  }

  /// 연동 안내를 사용자가 닫았다.
  void cancelLink() {
    if (state.linkRequest != null) state = state.copyWith(clearLinkRequest: true);
  }

  /// 네 갈래(소셜·이메일 로그인·가입·연동)가 성공/취소/실패를 똑같이 다룬다.
  Future<bool> _run(Future<AuthUser> Function() attempt) async {
    try {
      final user = await attempt();
      if (!mounted) return false;
      state = AuthState(user: user);
      return true;
    } on SocialLinkRequired catch (link) {
      // 실패가 아니다. 화면이 비밀번호를 물을 수 있도록 상태에 남긴다.
      if (mounted) {
        state = state.copyWith(
          clearPending: true,
          emailBusy: false,
          linkRequest: link,
        );
      }
      return false;
    } on SignInCancelled {
      // 사용자가 창을 닫았다. 오류 문구를 띄우면 자기가 한 행동을 실패로 안내받는 셈이다.
      if (mounted) state = state.copyWith(clearPending: true, emailBusy: false);
      return false;
    } on AuthException catch (e) {
      if (mounted) {
        state = state.copyWith(clearPending: true, emailBusy: false, error: e);
      }
      return false;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          clearPending: true,
          emailBusy: false,
          error: AuthException('로그인에 실패했습니다 ($e)'),
        );
      }
      return false;
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    if (mounted) state = const AuthState();
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }
}

final socialSignInProvider = Provider<SocialSignIn>(
  (ref) => PlatformSocialSignIn(),
);

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) => AuthController(
      ref.watch(authRepositoryProvider),
    ));

/// `providers.dart` 가 아니라 여기 두는 이유: 인증 관련 의존이 한 파일에 모여야
/// 테스트에서 통째로 갈아끼우기 쉽다.
final authRepositoryProvider = Provider<AuthRepository>((ref) => RemoteAuthRepository(
  client: ref.watch(apiClientProvider),
  socialSignIn: ref.watch(socialSignInProvider),
));
