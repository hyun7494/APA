import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 누르는 동안 살짝 내려앉는 터치 피드백.
///
/// Material 기본 잉크 리플은 원형 물결이 퍼지는 모양이 강해서
/// "플러터 기본값"으로 읽힌다. 대신 요소 전체가 손가락 압력을 받아
/// 가라앉는 물리 반응으로 바꿨다.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;

  /// null이면 아무 것도 감싸지 않고 자식을 그대로 돌려준다.
  final VoidCallback? onTap;

  final double scale;
  final HitTestBehavior behavior;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    if (onTap == null) return widget.child;

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: AppMotion.instant,
        curve: AppMotion.press,
        child: widget.child,
      ),
    );
  }
}
