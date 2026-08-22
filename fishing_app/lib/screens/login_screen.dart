import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_controller.dart';
import '../services/auth_repository.dart';
import '../services/social_sign_in.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/auth_field.dart';
import '../widgets/press_scale.dart';
import '../widgets/reveal.dart';

/// 로그인 (기획서 v2 5-3).
///
/// **로그인은 강제되지 않는다.** 지수·도감·게시판은 비로그인으로 열리고(기획서 5-5),
/// 조과 등록·즐겨찾기·글쓰기처럼 `user_id` 가 필요한 자리에서만 여기로 보낸다.
/// 그래서 화면을 띄운 이유를 [reason] 으로 받아 위에 적어 준다 — 맥락 없이 로그인 화면이
/// 튀어나오면 사용자는 자기가 무엇을 하려 했는지부터 잊는다.
///
/// 수단은 둘이고 **무게가 같다** — 이메일과 소셜. 소셜만 두면 계정을 제공자에 묶는
/// 셈이고, 이메일만 두면 가입 자체가 부담이 된다.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.reason, this.redirectTo});

  /// "조과를 등록하려면 로그인이 필요해요" 같은 한 줄.
  final String? reason;

  /// 로그인 성공 후 돌아갈 경로. 없으면 홈으로 간다.
  final String? redirectTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// 입력 형식 오류처럼 **서버에 가기 전에** 우리가 아는 것. 서버가 준 문구
  /// ([AuthState.error])와 같은 자리에 그린다 — 사용자에게는 둘 다 그냥 "안 된 이유"다.
  String? _localError;

  @override
  void initState() {
    super.initState();
    // 고치기 시작하면 지운다. 방금 바꾼 값에 대한 판정이 아직 없는데
    // 빨간 문구가 남아 있으면 그것부터 의심하게 된다.
    _email.addListener(_clearErrors);
    _password.addListener(_clearErrors);
  }

  void _clearErrors() {
    if (_localError != null) setState(() => _localError = null);
    ref.read(authControllerProvider.notifier).clearError();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
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
            // 입력 칸이 생긴 뒤로는 스크롤이 필수다. 키보드가 올라오면 화면의
            // 절반이 덮이는데, 고정 레이아웃이면 로그인 버튼에 닿을 수 없다.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  8,
                  AppSpacing.screen,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Reveal(child: _header()),
                    const SizedBox(height: 28),
                    Reveal(index: 1, child: _emailForm(auth)),
                    const SizedBox(height: 22),
                    const Reveal(index: 2, child: AuthDivider()),
                    const SizedBox(height: 16),
                    ..._socialButtons(auth),
                    const SizedBox(height: 18),
                    Text(
                      '로그인하면 서비스 이용약관과 개인정보 처리방침에 동의하는 것으로 봅니다.',
                      style: AppText.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
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
          widget.reason ?? '로그인하면 잡은 물고기를 기록하고\n도감을 모을 수 있어요.',
          style: AppText.body,
        ),
      ],
    );
  }

  Widget _emailForm(AuthState auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthField(
          controller: _email,
          hint: '이메일',
          icon: AppIcon.user,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.next,
          enabled: !auth.isBusy,
        ),
        const SizedBox(height: 10),
        AuthField(
          controller: _password,
          hint: '비밀번호',
          icon: AppIcon.lock,
          obscure: true,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          enabled: !auth.isBusy,
          onSubmitted: _signInWithEmail,
        ),
        const SizedBox(height: 14),
        // 방금 누른 버튼 **바로 위**다. 화면 맨 아래 스낵바로 띄우면 눈이 가지 않는다.
        AuthErrorBox(message: _localError ?? auth.error?.message),
        _BusyButton(
          label: '로그인',
          busy: auth.emailBusy,
          onPressed: auth.isBusy ? null : _signInWithEmail,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('아직 계정이 없나요?', style: AppText.caption),
            const SizedBox(width: 6),
            PressScale(
              onTap: auth.isBusy ? null : () => _goToSignUp(context),
              scale: 0.96,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Text(
                  '회원가입',
                  style: AppText.caption.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _socialButtons(AuthState auth) {
    return [
      for (final provider in SocialProvider.values) ...[
        Reveal(
          index: SocialProvider.values.indexOf(provider) + 3,
          child: _ProviderButton(
            provider: provider,
            busy: auth.pending == provider,
            // 진행 중에는 다른 버튼도 막는다. 카카오 창이 뜬 사이에 구글을 누르면
            // 두 로그인이 겹쳐 어느 쪽 결과가 남을지 알 수 없다.
            enabled: !auth.isBusy,
            onTap: () => _signInWithSocial(provider),
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  Future<void> _signInWithEmail() async {
    // 서버도 검사하지만, 왕복 한 번을 돌고 와서 "입력해 주세요"를 듣는 것은 낭비다.
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _localError = '이메일과 비밀번호를 입력해 주세요');
      return;
    }

    final ok = await ref.read(authControllerProvider.notifier).signInWithEmail(
      email: _email.text.trim(),
      password: _password.text,
    );
    if (ok && mounted) _leave(context);
  }

  Future<void> _signInWithSocial(SocialProvider provider) async {
    final notifier = ref.read(authControllerProvider.notifier);
    final ok = await notifier.signIn(provider);
    if (!mounted) return;
    if (ok) {
      _leave(context);
      return;
    }

    // 실패가 아니라 "한 단계 더" 인 경우 — 같은 이메일의 계정이 이미 있다.
    final link = ref.read(authControllerProvider).linkRequest;
    if (link != null) await _askToLink(link);
  }

  /// 계정 연동 안내. 비밀번호를 받아 두 신원을 한 계정으로 합친다.
  ///
  /// 여기서 그냥 새 계정을 만들면 사용자는 **같은 이메일로 계정 두 개**를 갖게 되고,
  /// 도감과 조과가 어느 쪽에 쌓였는지 알 수 없게 된다.
  /// @param error 앞선 시도의 실패 문구. **대화상자 안에** 그린다 —
  ///              화면의 오류 자리는 이 대화상자에 가려서 보이지 않는다.
  Future<void> _askToLink(SocialLinkRequired link, {String? error}) async {
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LinkDialog(link: link, error: error),
    );
    if (!mounted) return;

    final notifier = ref.read(authControllerProvider.notifier);
    if (password == null) {
      notifier.cancelLink();
      return;
    }

    final ok = await notifier.confirmLink(password);
    if (!mounted) return;
    if (ok) {
      _leave(context);
      return;
    }

    // 비밀번호를 잘못 친 것뿐일 수 있다. 소셜 로그인부터 다시 시키지 않고 다시 묻되,
    // **왜 실패했는지를 들고** 간다. 그냥 다시 물으면 사용자는 무엇이 틀렸는지 모른다.
    final message = ref.read(authControllerProvider).error?.message;
    notifier.clearError();
    await _askToLink(link, error: message ?? '비밀번호가 올바르지 않습니다');
  }

  void _goToSignUp(BuildContext context) => context.push(
    '/signup',
    extra: <String, String?>{'redirectTo': widget.redirectTo},
  );

  void _leave(BuildContext context) => context.go(widget.redirectTo ?? '/home');
}

/// 눌린 동안 스피너로 바뀌는 주 버튼. 라벨만 두면 서버를 기다리는 몇 초 동안
/// 아무 일도 일어나지 않은 것처럼 보여 사용자가 계속 다시 누른다.
class _BusyButton extends StatelessWidget {
  const _BusyButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (!busy) return PrimaryButton(label: label, onPressed: onPressed);

    return Container(
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
    );
  }
}

/// 계정 연동 확인 창.
class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.link, this.error});

  final SocialLinkRequired link;

  /// 앞선 시도가 실패한 이유. 없으면 첫 시도다.
  final String? error;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_password.text.isEmpty) return;
    Navigator.of(context).pop(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    final providerLabel = widget.link.provider == SocialProvider.kakao
        ? '카카오'
        : 'Google';

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
      ),
      title: Text('계정을 연결할까요?', style: AppText.sectionTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.link.email} 로 가입한 계정이 이미 있어요.\n'
            '비밀번호를 입력하면 다음부터 $providerLabel 로도 같은 계정으로 들어올 수 있어요.',
            style: AppText.bodySmall,
          ),
          const SizedBox(height: 16),
          AuthErrorBox(message: widget.error),
          // 카드 위가 아니라 대화상자 안이라 흰 면이 배경과 겹친다. 회색 면으로 눌러 넣는다.
          Container(
            decoration: BoxDecoration(
              color: AppColors.fill,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            height: 50,
            child: TextField(
              controller: _password,
              obscureText: true,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              cursorColor: AppColors.accent,
              style: AppText.infoValue,
              decoration: InputDecoration(
                hintText: '비밀번호',
                hintStyle: AppText.infoValue.copyWith(color: AppColors.faint),
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('취소', style: AppText.rowLabel),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            '연결하기',
            style: AppText.rowValue.copyWith(color: AppColors.accent),
          ),
        ),
      ],
    );
  }
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
