import 'package:flutter/material.dart';

import '../models/rating.dart';
import '../theme/app_theme.dart';

/// 등급 배지 — 색면 + 글자.
///
/// 앞의 점 표시를 뺐다. 등급 구분은 색으로 충분하고 점은 폭만 늘린다.
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating, this.compact = false});

  final Rating rating;

  /// 목록 행처럼 자리가 좁을 때
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: rating.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        rating.label,
        style: AppText.badge.copyWith(
          color: rating.foreground,
          fontSize: compact ? 12 : 13,
        ),
      ),
    );
  }
}

/// 4점 만점 점수 배지 — 홈 지수 카드에서 등급 글자 옆에 붙는다.
class RatingScoreBadge extends StatelessWidget {
  const RatingScoreBadge({super.key, required this.rating});

  final Rating rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: rating.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        rating.score,
        style: AppText.badge.copyWith(
          color: rating.foreground,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
