import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_controller.dart';
import '../services/social_sign_in.dart';
import '../theme/app_theme.dart';
import '../widgets/press_scale.dart';
import '../widgets/reveal.dart';

/// 로그인 (기획서 v2 5-3).
///
/// **로그인은 강제되지 않는다.** 지수·도감·게시판은 비로그인으로 열리고(기획서 5-5),
/// 조과 등록·즐겨찾기·글쓰기처럼 `user_id` 가 필요한 자리에서만 여기로 보낸다.
/// 그래서 화면을 띄운 이유를 [reason] 으로 받아 위에 적어 준다 — 맥락 없이 로그인 화면이
/// 튀어나오면 사용자는 자기가 무엇을 하려 했는지부터 잊는다.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key, this.reason, this.redirectTo});

  /// "조과를 등록하려면 로그인이 필요해요" 같은 한 줄.
  final String? reason;

  /// 로그인 성공 후 돌아갈 경로. 없으면 홈으로 간다.
  final String? redirectTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
      final error = next.error;
      if (error != null && error != previous?.error) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
        ref.read(authControllerProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: auth.isBusy ? null : () => _leave(context),
                  child: Text('나중에 하기', style: AppText.rowLabel),
                ),
              ),
              const Spacer(flex: 2),

              Reveal(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
                      ),
                      child: const Center(
                        child: LineIcon(
                          AppIcon.book,
                          size: 26,
                          color: AppColors.accent,
                          stroke: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('내 도감을\n채워볼까요?', style: AppText.pageTitle),
                    const SizedBox(height: 12),
                    Text(
                      reason ?? '로그인하면 잡은 물고기를 기록하고\n도감을 모을 수 있어요.',
                      style: AppText.body,
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              for (final provider in SocialProvider.values) ...[
                Reveal(
                  index: SocialProvider.values.indexOf(provider) + 1,
                  child: _ProviderButton(
                    provider: provider,
                    busy: auth.pending == provider,
                    // 진행 중에는 다른 버튼도 막는다. 카카오 창이 뜬 사이에 구글을 누르면
                    // 두 로그인이 겹쳐 어느 쪽 결과가 남을지 알 수 없다.
                    enabled: !auth.isBusy,
                    onTap: () => _signIn(context, ref, provider),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              const SizedBox(height: 10),
              Text(
                '로그인하면 서비스 이용약관과 개인정보 처리방침에 동의하는 것으로 봅니다.',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signIn(
    BuildContext context,
    WidgetRef ref,
    SocialProvider provider,
  ) async {
    final ok = await ref.read(authControllerProvider.notifier).signIn(provider);
    if (ok && context.mounted) _leave(context);
  }

  void _leave(BuildContext context) => context.go(redirectTo ?? '/home');
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.provider,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final SocialProvider provider;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  /// 카카오는 브랜드 색을 그대로 쓴다 — 사용자가 색으로 먼저 알아본다.
  static const _kakaoYellow = Color(0xFFFEE500);
  static const _kakaoBrown = Color(0xFF191600);

  @override
  Widget build(BuildContext context) {
    final isKakao = provider == SocialProvider.kakao;
    final background = isKakao ? _kakaoYellow : AppColors.surface;
    final foreground = isKakao ? _kakaoBrown : AppColors.ink;

    return Opacity(
      opacity: enabled || busy ? 1 : 0.5,
      child: PressScale(
        onTap: enabled ? onTap : null,
        scale: 0.98,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            // 흰 버튼은 회색 배경에서 경계가 사라진다. 카카오는 노란 면이라 필요 없다.
            border: isKakao ? null : Border.all(color: AppColors.line),
          ),
          child: busy
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(foreground),
                  ),
                )
              : Text(
                  provider.label,
                  style: AppText.rowValue.copyWith(color: foreground),
                ),
        ),
      ),
    );
  }
}
