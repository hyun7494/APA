import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'press_scale.dart';

/// 바닥에 붙는 흰 탭 바.
///
/// v2에서 떠 있는 유리 아일랜드를 걷어냈다. 시안(`Deep Tide v2.dc.html`)은
/// 좌우 끝까지 닿는 흰 면에 위쪽 1px 그림자 한 줄만 얹는다 — 블러도,
/// 알약도, 미끄러지는 인디케이터도 없다. 선택은 색과 굵기로만 나타낸다.
///
/// Rev 2에서 2번째 탭이 `운세` → `도감`으로 바뀌었다.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  /// 브랜치 인덱스 — 0 지수 / 1 도감 / 2 홈 / 3 게시판 / 4 마이
  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const homeIndex = 2;

  static const _items = <({AppIcon icon, String label})>[
    (icon: AppIcon.wave, label: '지수'),
    (icon: AppIcon.book, label: '도감'),
    (icon: AppIcon.compass, label: '홈'),
    (icon: AppIcon.chat, label: '게시판'),
    (icon: AppIcon.user, label: '마이'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(
        top: 8,
        // 시안의 22px는 제스처 바가 없는 기기 기준이다. 인셋이 있으면
        // 그쪽을 쓴다 — 둘을 더하면 바가 쓸데없이 두꺼워진다.
        bottom: bottomInset > 0 ? bottomInset : 22,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.topLine,
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: _Tab(
                item: _items[i],
                active: currentIndex == i,
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.active, required this.onTap});

  final ({AppIcon icon, String label}) item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.ink : AppColors.faint;

    return PressScale(
      onTap: onTap,
      scale: 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LineIcon(
            item.icon,
            size: 24,
            color: color,
            stroke: active ? 1.7 : 1.45,
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: AppMotion.fast,
            curve: AppMotion.state,
            style: AppText.navLabel.copyWith(
              color: color,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            ),
            child: Text(item.label),
          ),
        ],
      ),
    );
  }
}
