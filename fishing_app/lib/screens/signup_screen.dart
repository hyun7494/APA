import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/legal_documents.dart';
import '../services/auth_controller.dart';
import '../services/auth_repository.dart';
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

  /// 서버에 가기 전에 우리가 아는 오류. 서버가 준 문구와 같은 자리에 그린다.
  String? _localError;

  /// 항목별 체크 상태. 코드(`TERMS_OF_SERVICE` 등)를 키로 쓴다.
  final _agreed = <String, bool>{
    for (final doc in signUpConsents) doc.consentType: false,
  };

  bool get _requiredAgreed => signUpConsents
      .where((doc) => doc.required)
      .every((doc) => _agreed[doc.consentType] == true);

  bool get _allAgreed => _agreed.values.every((v) => v);

  void _setAll(bool value) => setState(() {
    for (final key in _agreed.keys) {
      _agreed[key] = value;
    }
  });

  /// 서버 규칙과 같은 값이다 (`PasswordPolicy.MIN_LENGTH`).
  static const _minPasswordLength = 8;

  @override
  void initState() {
    super.initState();
    // 고치기 시작하면 지운다 — 방금 바꾼 값에 대한 판정이 아직 없는데
    // 빨간 문구가 남아 있으면 그것부터 의심하게 된다.
    for (final field in [_email, _password, _passwordConfirm, _nickname]) {
      field.addListener(_clearErrors);
    }
  }

  void _clearErrors() {
    if (_localError != null) setState(() => _localError = null);
    ref.read(authControllerProvider.notifier).clearError();
  }

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
              const SizedBox(height: 26),

              // ★ 동의는 **읽을 수 있어야** 동의다. 예전엔 "동의하는 것으로 봅니다" 라는
              //   회색 한 줄이 전부였는데, 읽을 문서가 어디에도 없었고 개인정보보호법이
              //   요구하는 명시적 동의도 아니었다.
              _ConsentSection(
                agreed: _agreed,
                allAgreed: _allAgreed,
                enabled: !auth.isBusy,
                onToggleAll: _setAll,
                onToggle: (type, value) => setState(() => _agreed[type] = value),
                onOpen: (doc) => context.push('/legal/${doc.consentType}'),
              ),
              const SizedBox(height: 24),

              // 방금 누른 버튼 바로 위. "이미 가입된 이메일입니다" 를 스낵바로 4초 띄우면
              // 그 뒤로 무엇을 해야 할지(로그인하러 갈지) 정할 시간이 없다.
              AuthErrorBox(message: _localError ?? auth.error?.message),

              if (auth.emailBusy)
                Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.emphasis,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SizedBox(
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
                  // 필수 동의 전에는 누를 수 없다. 눌러 놓고 거절하는 것보다
                  // 못 누르는 편이 무엇이 남았는지 분명하다.
                  onPressed: auth.isBusy || !_requiredAgreed ? null : _submit,
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

    if (email.isEmpty) return _fail('이메일을 입력해 주세요');
    if (password.length < _minPasswordLength) {
      return _fail('비밀번호는 $_minPasswordLength자 이상이어야 합니다');
    }
    if (password != _passwordConfirm.text) {
      return _fail('비밀번호가 서로 다릅니다');
    }
    if (nickname.isEmpty) return _fail('닉네임을 입력해 주세요');

    if (!_requiredAgreed) return _fail('필수 항목에 동의해 주세요');

    final ok = await ref.read(authControllerProvider.notifier).signUp(
      email: email,
      password: password,
      nickname: nickname,
      // 사용자가 **실제로 본 판**을 그대로 보낸다. 거부한 선택 항목도 보낸다 —
      // "묻지 않았다" 와 "물었고 거절했다" 는 다른 사실이다.
      consents: [
        for (final doc in signUpConsents)
          ConsentAnswer(
            type: doc.consentType,
            version: doc.version,
            agreed: _agreed[doc.consentType] ?? false,
          ),
      ],
    );
    if (!ok || !mounted) return;

    // 가입과 동시에 로그인됐다. 로그인 화면으로 되돌리지 않고 원래 가려던 곳으로 보낸다.
    context.go(widget.redirectTo ?? '/home');
  }

  void _fail(String message) => setState(() => _localError = message);
}


/// 약관 동의 묶음 — 스크롤 되는 본문 한 칸 + 전체 동의 + 항목별 체크.
///
/// **본문을 먼저 보여 준다.** 체크박스만 늘어놓고 문서는 다른 화면에 숨겨 두면,
/// 읽지 않고 누르는 것이 기본 동작이 된다. 여기 뜬 상자 안에서 그대로 읽을 수 있고,
/// 항목의 `>` 를 누르면 전문을 큰 화면으로 볼 수 있다.
class _ConsentSection extends StatelessWidget {
  const _ConsentSection({
    required this.agreed,
    required this.allAgreed,
    required this.enabled,
    required this.onToggleAll,
    required this.onToggle,
    required this.onOpen,
  });

  final Map<String, bool> agreed;
  final bool allAgreed;
  final bool enabled;
  final void Function(bool value) onToggleAll;
  final void Function(String type, bool value) onToggle;
  final void Function(LegalDocument doc) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 스크롤 되는 본문 칸. 높이를 고정해야 "스크롤 해서 읽는 것" 이 된다 —
        // 늘어나게 두면 가입 폼이 문서 길이만큼 길어져 아무도 안 읽는다.
        Container(
          height: 150,
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.cardTight),
            border: Border.all(color: AppColors.line),
          ),
          child: Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final doc in readableDocuments) ...[
                    Text(doc.title, style: AppText.cardLabel),
                    const SizedBox(height: 6),
                    Text(
                      doc.body.trim(),
                      style: AppText.caption.copyWith(height: 1.6),
                    ),
                    const SizedBox(height: 18),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        _ConsentRow(
          label: '전체 동의',
          checked: allAgreed,
          enabled: enabled,
          emphasized: true,
          onChanged: onToggleAll,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Divider(),
        ),

        for (final doc in signUpConsents)
          _ConsentRow(
            label: '${doc.required ? '(필수)' : '(선택)'} ${doc.title}',
            note: doc.summary,
            checked: agreed[doc.consentType] ?? false,
            enabled: enabled,
            onChanged: (value) => onToggle(doc.consentType, value),
            onOpen: doc.hasBody ? () => onOpen(doc) : null,
          ),
      ],
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.label,
    required this.checked,
    required this.enabled,
    required this.onChanged,
    this.note,
    this.onOpen,
    this.emphasized = false,
  });

  final String label;
  final String? note;
  final bool checked;
  final bool enabled;
  final void Function(bool value) onChanged;
  final VoidCallback? onOpen;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 체크박스만이 아니라 **라벨까지 눌러도 켜진다.** 작은 네모만 겨냥하게
          // 두면 손가락으로는 잘 안 맞는다.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? () => onChanged(!checked) : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 아이콘 세트에 체크박스가 없다. 새 아이콘을 넣기보다 네모를
                  // 그리고 안에 `check` 를 넣는다 — 표준적인 모양이고 팔레트만 탄다.
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Container(
                      width: 19,
                      height: 19,
                      decoration: BoxDecoration(
                        color: checked ? AppColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: checked ? AppColors.accent : AppColors.line,
                          width: 1.4,
                        ),
                      ),
                      child: checked
                          ? Center(
                              child: LineIcon(
                                AppIcon.check,
                                size: 12,
                                color: AppColors.onAccent,
                                stroke: 2,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: emphasized
                              ? AppText.sectionTitle
                              : AppText.rowLabel,
                        ),
                        if (note != null) ...[
                          const SizedBox(height: 2),
                          Text(note!, style: AppText.caption),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onOpen != null) LegalChevron(onTap: onOpen!),
        ],
      ),
    );
  }
}


/// 약관 전문을 여는 `>`.
///
/// 따로 이름을 준 이유는 **테스트가 겨냥할 것이 필요해서**다. 화면에 `>` 가 여럿이라
/// 아이콘만으로는 어느 것인지 못 고른다.
class LegalChevron extends StatelessWidget {
  const LegalChevron({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: LineIcon(
          AppIcon.chevronRight,
          size: 14,
          color: AppColors.faint,
          stroke: 1.5,
        ),
      ),
    );
  }
}
