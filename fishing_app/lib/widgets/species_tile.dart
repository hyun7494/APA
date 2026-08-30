import 'package:flutter/material.dart';

import '../models/species.dart';
import '../theme/app_theme.dart';
import 'authed_photo.dart';
import 'photo_placeholder.dart';
import 'press_scale.dart';

/// 도감 한 칸.
///
/// 기록한 칸은 내가 찍은 사진이 표지가 되고, 우하단에 기록 횟수가 붙는다.
/// 희귀는 골드 줄무늬 + 좌상단 메달.
///
/// **미기록 칸은 자물쇠가 아니라 어종 실루엣이다** — 잠긴 게 아니라 아직
/// 안 만난 종이라는 뜻이다.
///
/// ⚠️ **이름은 가린 적이 없어야 한다.** 기획서 2-3 이 `LOCKED` 의 이름을 "회색 텍스트로
/// 노출" 로 못박고 이유까지 적어 뒀다 — *뭘 잡아야 할지 알아야 다음 출조 동기가 생긴다.*
/// 한동안 이름 자리에 "미기록"·"희귀" 만 넣었는데, 그러면 36칸이 글자도 그림도 전부
/// 같아져서 도감을 열어도 읽을 게 없다. 희귀 여부는 이름 색으로 구분한다.
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
              entry.species.name,
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
        // 등록된 칸은 표지 사진, 미등록은 줄무늬. coverPhotoUrl 은 미등록이면 null 이다.
        AuthedPhoto(path: entry.coverPhotoUrl, rare: rare, thumb: true),
        if (rare)
          Positioned(
            left: 6,
            top: 6,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold,
              ),
              child: Center(
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: rare ? AppColors.goldSoft : AppColors.fill,
        // ⚠️ 테두리를 빼지 말 것. 라이트에서 fill(#F4F5F7)이 화면 배경과 거의 같아서
        //    칸이 안 보이고, 그러면 격자가 아니라 아이콘이 떠 있는 것처럼 읽힌다.
        //    다크는 카드가 배경보다 밝아 원래 보였다 — 라이트에서만 무너지던 자리다.
        border: Border.all(color: AppColors.line),
      ),
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
