import 'package:flutter/material.dart';

import '../models/spot.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';
import 'rating_badge.dart';

/// 지수 목록의 포인트 카드.
///
/// 카드 전체가 이미 하나의 목적지라 안에 "상세 보기" 버튼을 따로 두지 않고,
/// 하단 물때 줄 끝에 얇은 화살표만 남겼다.
class SpotCard extends StatelessWidget {
  const SpotCard({super.key, required this.spot, required this.onOpen});

  final Spot spot;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      style: AppText.sectionTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // ⚠️ 권역 이름을 여기 다시 적지 않는다. 이 카드는 지수 목록에서만
                    //    쓰이는데, 바로 위 칩이 이미 그 권역을 고른 상태다 —
                    //    권역이 4개로 묶인 뒤로 14장이 전부 "동해" 를 반복했다.
                    //    지역이 정보가 되는 자리는 검색 결과다 (거기선 따로 그린다).
                  ],
                ),
              ),
              const SizedBox(width: 10),
              RatingBadge(rating: spot.rating),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            spot.comment,
            style: AppText.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: MetricColumn(
                  icon: AppIcon.thermometer,
                  label: '수온',
                  value: Spot.metric(spot.waterTemp),
                  unit: '℃',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricColumn(
                  icon: AppIcon.swell,
                  label: '파고',
                  value: Spot.metric(spot.waveHeight),
                  unit: 'm',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricColumn(
                  icon: AppIcon.wind,
                  label: '풍속',
                  value: Spot.metric(spot.windSpeed),
                  unit: '㎧',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              LineIcon(
                AppIcon.moon,
                size: 15,
                color: AppColors.chipBlueFg,
                stroke: 1.4,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  spot.tideInfo,
                  style: AppText.rowLabel.copyWith(color: AppColors.body),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              LineIcon(
                AppIcon.chevronRight,
                size: 15,
                color: AppColors.faint,
                stroke: 1.5,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
