import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 로그인·회원가입 화면의 입력 한 칸.
///
/// 회색 배경 위 흰 면 한 겹이다 — 앱의 다른 화면과 같은 문법이라 테두리를 두지 않는다.
/// 대신 포커스가 들어오면 주색 링이 생겨서 **지금 어디에 타이핑하는지**가 보인다.
/// 보더 없는 면만으로는 그것을 알 수 없다.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.keyboardType,
    this.obscure = false,
    this.autofillHints,
    this.textInputAction,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final AppIcon? icon;
  final TextInputType? keyboardType;

  /// 비밀번호 칸. 오른쪽에 보기/숨기기 토글이 붙는다 —
  /// 가려진 채로만 치게 하면 오타를 찾을 방법이 없다.
  final bool obscure;

  final List<String>? autofillHints;
  final TextInputAction? textInputAction;
  final bool enabled;
  final VoidCallback? onSubmitted;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  final _focus = FocusNode();
  late bool _hidden = widget.obscure;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final icon = widget.icon;

    return Opacity(
      opacity: widget.enabled ? 1 : 0.5,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: focused ? AppColors.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              LineIcon(
                icon,
                size: 18,
                color: focused ? AppColors.accent : AppColors.faint,
                stroke: 1.6,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                enabled: widget.enabled,
                obscureText: _hidden,
                keyboardType: widget.keyboardType,
                autofillHints: widget.autofillHints,
                textInputAction: widget.textInputAction,
                onSubmitted: (_) => widget.onSubmitted?.call(),
                cursorColor: AppColors.accent,
                style: AppText.infoValue,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: AppText.infoValue.copyWith(color: AppColors.faint),
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
            ),
            if (widget.obscure)
              GestureDetector(
                onTap: () => setState(() => _hidden = !_hidden),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    _hidden ? '보기' : '숨기기',
                    style: AppText.caption.copyWith(color: AppColors.label),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "또는" 을 가운데 둔 구분선. 자체 로그인과 소셜 로그인이 **같은 무게의 선택지**라는
/// 것을 보여 준다 — 한쪽을 아래에 작게 붙이면 부차적인 수단처럼 읽힌다.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, this.label = '또는'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.disabled, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: AppText.caption),
        ),
        const Expanded(child: Divider(color: AppColors.disabled, height: 1)),
      ],
    );
  }
}
