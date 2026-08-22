import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/auth_field.dart';
import '../widgets/reveal.dart';

/// 자체 회원가입 (이메일 + 비밀번호).
///
/// 받는 것은 셋뿐이다 — 이메일·비밀번호·닉네임. 낚시 경력이나 지역 같은 것을 여기서
/// 물으면 가입 자체를 그만둔다. 프로필은 나중에 마이페이지에서 채우면 된다.
///
/// 가입에 성공하면 **곧바로 로그인 상태**가 된다. 서버가 가입 응답에 토큰을 함께
/// 내려주기 때문이다 — 방금 만든 비밀번호를 다시 치게 할 이유가 없다.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key, this.redirectTo});

  /// 가입 후 돌아갈 경로. 로그인 화면이 받은 것을 그대로 넘겨준다.
  final String? redirectTo;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _nickname = TextEditingController();

  /// 서버 규칙과 같은 값이다 (`PasswordPolicy.MIN_LENGTH`).
  static const _minPasswordLength = 8;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _nickname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
      final error = next.error;
      if (error != null && error != previous?.error) {
        _toast(error.message);
        ref.read(authControllerProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const LineIcon(AppIcon.chevronLeft, size: 22),
          onPressed: auth.isBusy ? null : () => context.pop(),
        ),
        title: const Text('회원가입'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            8,
            AppSpacing.screen,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Reveal(
                child: Text(
                  '이메일로 시작하기',
                  style: AppText.pageTitle,
                ),
              ),
              const SizedBox(height: 10),
              Reveal(
                child: Text(
                  '카카오·Google 계정은 나중에 연결할 수 있어요.\n'
                  '같은 이메일이면 하나의 계정으로 이어집니다.',
                  style: AppText.body,
                ),
              ),
              const SizedBox(height: 28),

              Reveal(
                index: 1,
                child: _label('이메일'),
              ),
              const SizedBox(height: 8),
              Reveal(
                index: 1,
                child: AuthField(
                  controller: _email,
                  hint: 'name@example.com',
                  icon: AppIcon.user,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.newUsername],
                  textInputAction: TextInputAction.next,
                  enabled: !auth.isBusy,
                ),
              ),
              const SizedBox(height: 18),

              Reveal(index: 2, child: _label('비밀번호')),
              const SizedBox(height: 8),
              Reveal(
                index: 2,
                child: AuthField(
                  controller: _password,
                  hint: '$_minPasswordLength자 이상',
                  icon: AppIcon.lock,
                  obscure: true,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  enabled: !auth.isBusy,
                ),
              ),
              const SizedBox(height: 10),
              Reveal(
                index: 2,
                child: AuthField(
                  controller: _passwordConfirm,
                  hint: '비밀번호 확인',
                  icon: AppIcon.check,
                  obscure: true,
                  textInputAction: TextInputAction.next,
                  enabled: !auth.isBusy,
                ),
              ),
              const SizedBox(height: 18),

              Reveal(index: 3, child: _label('닉네임')),
              const SizedBox(height: 8),
              Reveal(
                index: 3,
                child: AuthField(
                  controller: _nickname,
                  hint: '도감과 게시판에 표시돼요',
                  icon: AppIcon.fish,
                  textInputAction: TextInputAction.done,
                  enabled: !auth.isBusy,
                  onSubmitted: _submit,
                ),
              ),
              const SizedBox(height: 28),

              if (auth.emailBusy)
                Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.onAccent),
                    ),
                  ),
                )
              else
                PrimaryButton(
                  label: '가입하고 시작하기',
                  onPressed: auth.isBusy ? null : _submit,
                ),

              const SizedBox(height: 16),
              Text(
                '가입하면 서비스 이용약관과 개인정보 처리방침에 동의하는 것으로 봅니다.',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: AppText.overline);

  /// 서버도 같은 것을 검사하지만, **비밀번호 확인만은 여기서만 볼 수 있다** —
  /// 서버는 한 번만 받으므로 두 칸이 다른지 알 방법이 없다.
  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    final nickname = _nickname.text.trim();

    if (email.isEmpty) return _toast('이메일을 입력해 주세요');
    if (password.length < _minPasswordLength) {
      return _toast('비밀번호는 $_minPasswordLength자 이상이어야 합니다');
    }
    if (password != _passwordConfirm.text) {
      return _toast('비밀번호가 서로 다릅니다');
    }
    if (nickname.isEmpty) return _toast('닉네임을 입력해 주세요');

    final ok = await ref.read(authControllerProvider.notifier).signUp(
      email: email,
      password: password,
      nickname: nickname,
    );
    if (!ok || !mounted) return;

    // 가입과 동시에 로그인됐다. 로그인 화면으로 되돌리지 않고 원래 가려던 곳으로 보낸다.
    context.go(widget.redirectTo ?? '/home');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
