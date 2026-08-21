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
    this.error,
  });

  final AuthUser? user;

  /// 진행 중인 제공자. null 이면 대기 상태다.
  final SocialProvider? pending;

  final AuthException? error;

  bool get isLoggedIn => user != null;
  bool get isBusy => pending != null;

  AuthState copyWith({
    AuthUser? user,
    SocialProvider? pending,
    AuthException? error,
    bool clearUser = false,
    bool clearPending = false,
    bool clearError = false,
  }) => AuthState(
    user: clearUser ? null : (user ?? this.user),
    pending: clearPending ? null : (pending ?? this.pending),
    error: clearError ? null : (error ?? this.error),
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

  Future<bool> signIn(SocialProvider provider) async {
    if (state.isBusy) return false;
    state = state.copyWith(pending: provider, clearError: true);

    try {
      final user = await _repository.signIn(provider);
      if (!mounted) return false;
      state = AuthState(user: user);
      return true;
    } on SignInCancelled {
      // 사용자가 창을 닫았다. 오류 문구를 띄우면 자기가 한 행동을 실패로 안내받는 셈이다.
      if (mounted) state = state.copyWith(clearPending: true);
      return false;
    } on AuthException catch (e) {
      if (mounted) state = state.copyWith(clearPending: true, error: e);
      return false;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          clearPending: true,
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
