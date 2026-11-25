import 'package:fishing_app/theme/app_icons.dart';
import 'package:fishing_app/widgets/app_buttons.dart';
import 'package:fishing_app/widgets/pill_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 스크린 리더가 버튼을 "이름 있는 버튼" 으로, 켜짐 상태를 "선택됨" 으로 읽는지.
void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('아이콘만 있는 버튼도 이름과 버튼 역할을 갖는다', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(
      IconTapButton(icon: AppIcon.trash, label: '기록 지우기', onPressed: () {}),
    ));

    expect(
      tester.getSemantics(find.bySemanticsLabel('기록 지우기')),
      matchesSemantics(
        label: '기록 지우기',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('못 누르는 아이콘 버튼은 꺼진 버튼으로 읽힌다', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(
      const IconTapButton(
          icon: AppIcon.chevronLeft, label: '나중에 하기', onPressed: null),
    ));

    expect(
      tester.getSemantics(find.bySemanticsLabel('나중에 하기')),
      matchesSemantics(
          label: '나중에 하기', isButton: true, hasEnabledState: true),
    );
    semantics.dispose();
  });

  testWidgets('필터 칩은 글자를 이름으로, 켜짐을 선택됨으로 알린다', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(
      Row(mainAxisSize: MainAxisSize.min, children: [
        SquareChip(label: '전체', selected: true, onTap: () {}),
        SquareChip(label: '조황', selected: false, onTap: () {}),
      ]),
    ));

    expect(tester.getSemantics(find.bySemanticsLabel('전체')),
        isSemantics(isButton: true, isSelected: true));
    expect(tester.getSemantics(find.bySemanticsLabel('조황')),
        isSemantics(isButton: true, isSelected: false));
    semantics.dispose();
  });
}
