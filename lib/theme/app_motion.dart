import 'package:flutter/animation.dart';

/// 모션 토큰.
///
/// 기본 `Curves.easeInOut`은 쓰지 않는다. 관성이 있는 물체처럼
/// 빠르게 출발해 길게 감속하는 커브만 사용해 무게감을 만든다.
abstract final class AppMotion {
  /// 공간 이동 — 화면 진입, 카드 등장, 시트 전개.
  /// 초반 가속이 강하고 꼬리가 아주 긴 커브.
  static const spatial = Cubic(0.32, 0.72, 0, 1);

  /// 상태 전환 — 칩 선택, 색 변화처럼 위치가 바뀌지 않는 변화.
  static const state = Cubic(0.4, 0, 0.2, 1);

  /// 눌림 — 버튼이 손가락을 따라 내려앉을 때.
  static const press = Cubic(0.2, 0, 0, 1);

  /// 값 채움 — 게이지, 막대그래프가 자라날 때.
  static const settle = Cubic(0.16, 1, 0.3, 1);

  static const instant = Duration(milliseconds: 140);
  static const fast = Duration(milliseconds: 260);
  static const base = Duration(milliseconds: 420);
  static const slow = Duration(milliseconds: 720);

  /// 리스트 항목이 차례로 등장할 때 항목당 지연.
  static const stagger = Duration(milliseconds: 70);

  /// 스태거가 무한정 길어지지 않도록 자르는 상한 인덱스.
  static const staggerCap = 8;
}
