import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 화면에 들어온 요소가 정적으로 "툭" 나타나지 않게 하는 등장 애니메이션.
///
/// 아래에서 위로 무겁게 밀려 올라오면서 페이드인한다. [index]를 주면
/// 그만큼 지연돼 리스트가 차례로 살아난다.
///
/// `transform`과 `opacity`만 건드린다 — 레이아웃을 다시 계산시키는
/// 속성(height, padding 등)은 애니메이션하지 않는다.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 26,
    this.duration = AppMotion.slow,
  });

  final Widget child;

  /// 스태거 순번. [AppMotion.staggerCap]에서 잘려 목록이 길어져도
  /// 마지막 항목이 한참 뒤에 뜨는 일이 없다.
  final int index;

  /// 시작 시점의 아래쪽 오프셋(px)
  final double offset;

  final Duration duration;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  /// 스태거 지연은 타이머가 아니라 커브의 앞쪽 빈 구간으로 만든다.
  /// `Future.delayed`를 쓰면 위젯이 사라진 뒤에도 취소할 수 없는 타이머가
  /// 남아, 위젯 테스트에서 "Timer is still pending"으로 새어 나온다.
  late final Duration _delay = AppMotion.stagger * _steps;

  int get _steps => widget.index.clamp(0, AppMotion.staggerCap);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration + _delay,
  );

  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _delay.inMicroseconds / (widget.duration + _delay).inMicroseconds,
      1,
      curve: AppMotion.spatial,
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _t.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// [Reveal]을 자식 목록에 순번대로 자동으로 씌운다.
/// `children: RevealGroup.wrap([...])` 형태로 쓴다.
abstract final class RevealGroup {
  static List<Widget> wrap(List<Widget> children, {int from = 0}) => [
    for (var i = 0; i < children.length; i++)
      Reveal(index: from + i, child: children[i]),
  ];
}
