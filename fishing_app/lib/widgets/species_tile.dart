import 'package:flutter/material.dart';

import '../models/species.dart';
import '../theme/app_theme.dart';
import 'photo_placeholder.dart';
import 'press_scale.dart';

/// 도감 한 칸.
///
/// 기록한 칸은 내가 찍은 사진이 표지가 되고, 우하단에 기록 횟수가 붙는다.
/// 희귀는 골드 줄무늬 + 좌상단 메달.
///
/// **미기록 칸은 자물쇠가 아니라 어종 실루엣이다** — 잠긴 게 아니라 아직
/// 안 만난 종이라는 뜻이고, 이름 자리에는 "미기록"만 둔다.
class SpeciesTile extends StatelessWidget {
  const SpeciesTile({super.key, required this.entry, required this.onTap});

  final CollectionEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rare = entry.species.rarity.isRare;
    final owned = entry.owned;

    return PressScale(
      onTap: onTap,
      scale: 0.96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.tile),
              child: owned
                  ? _RecordedFace(entry: entry, rare: rare)
                  : _EmptyFace(rare: rare),
            ),
          ),
          const SizedBox(height: 7),
          Flexible(
            child: Text(
              owned ? entry.species.name : (rare ? '희귀' : '미기록'),
              style: AppText.tileName.copyWith(
                color: owned
                    ? AppColors.ink
                    : (rare ? AppColors.lockedGoldText : AppColors.disabled),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// 기록한 칸 — 사진 표지 + 횟수.
class _RecordedFace extends StatelessWidget {
  const _RecordedFace({required this.entry, required this.rare});

  final CollectionEntry entry;
  final bool rare;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PhotoPlaceholder(rare: rare),
        if (rare)
          Positioned(
            left: 6,
            top: 6,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold,
              ),
              child: const Center(
                child: LineIcon(
                  AppIcon.medal,
                  size: 13,
                  color: AppColors.onAccent,
                  stroke: 1.8,
                ),
              ),
            ),
          ),
        Positioned(
          right: 6,
          bottom: 6,
          child: PhotoCountBadge(label: '${entry.catchCount}회'),
        ),
      ],
    );
  }
}

/// 아직 안 만난 칸 — 어종 실루엣.
class _EmptyFace extends StatelessWidget {
  const _EmptyFace({required this.rare});

  final bool rare;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: rare ? AppColors.goldSoft : AppColors.fill,
      child: Center(
        child: LineIcon(
          AppIcon.fish,
          size: 30,
          color: rare ? AppColors.silhouetteGold : AppColors.silhouette,
          stroke: 1.5,
        ),
      ),
    );
  }
}
