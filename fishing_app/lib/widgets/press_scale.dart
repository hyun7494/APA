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
    this.semanticLabel,
    this.selected,
  });

  final Widget child;

  /// null이면 눌리지 않는다. [semanticLabel] 도 없으면 아무 것도 감싸지 않고
  /// 자식을 그대로 돌려준다.
  final VoidCallback? onTap;

  /// 스크린 리더가 읽을 이름. **아이콘만 있는 버튼은 반드시 줄 것** — 글자가 없으면
  /// TalkBack 은 이름 없이 "버튼" 이라고만 읽는다. 글자가 있으면 생략해도 그 글자를 읽는다.
  final String? semanticLabel;

  /// 켜짐/꺼짐이 있는 버튼(탭·필터 칩·좋아요)이면 상태를 넘긴다. 색으로만 알리면
  /// 화면을 못 보는 사람에게는 전달되지 않는다. 상태가 없는 버튼은 null.
  final bool? selected;

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
    if (onTap == null && widget.semanticLabel == null) return widget.child;

    // GestureDetector 는 "누를 수 있다" 만 알리고 "버튼" 이라고는 안 알린다.
    // container 라야 안의 글자가 이 버튼의 이름으로 합쳐진다 (Material 버튼과 같은 방식).
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: onTap == null
          ? widget.child
          : GestureDetector(
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
            ),
    );
  }
}
