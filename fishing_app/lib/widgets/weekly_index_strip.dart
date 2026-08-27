import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// 주간 낚시지수 — 하루 한 칸, 일주일이 한눈에.
///
/// 숫자를 읽히려는 게 아니라 **흐름을 보이려는** 자리다. "주말이 좋네"가 즉시 읽히면
/// 제 몫을 한 것이고, 정확한 파고·풍속은 그 날을 눌러 상세에서 본다.
///
/// 가로 스크롤을 쓰지 않는다 — 일주일이 화면 밖으로 나가면 흐름을 못 본다.
/// 일곱 칸을 폭에 나눠 넣고, 대신 칸 안을 최소한만 채운다.
class WeeklyIndexStrip extends StatelessWidget {
  const WeeklyIndexStrip({super.key, required this.days, this.onTapDay});

  final List<DailyIndex> days;

  /// 하루를 누르면 부르는 콜백. 없으면 누를 수 없다.
  final void Function(DailyIndex day)? onTapDay;

  /// 막대가 자라는 칸의 높이. 등급 1~4가 이 안에서 4단으로 나뉜다.
  static const _trackHeight = 46.0;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _DayTile(
              day: days[i],
              // 날짜만 비교한다. 시각까지 보면 같은 날인데도 어긋난다.
              isToday: _sameDay(days[i].date, today),
              weekday: _weekdays[days[i].date.weekday - 1],
              trackHeight: _trackHeight,
              onTap: onTapDay == null ? null : () => onTapDay!(days[i]),
            ),
          ),
        ],
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.isToday,
    required this.weekday,
    required this.trackHeight,
    required this.onTap,
  });

  final DailyIndex day;
  final bool isToday;
  final String weekday;
  final double trackHeight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rating = day.rating;
    // 등급 1~4 → 막대 높이. 가장 나쁜 날도 칸이 비어 보이지 않게 바닥을 준다 —
    // 빈 칸은 "나쁨"이 아니라 "값 없음"으로 읽힌다.
    final fill = 0.28 + (rating.level - 1) / 3 * 0.72;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isToday ? '오늘' : weekday,
            style: AppText.caption.copyWith(
              color: isToday ? AppColors.accentDark : AppColors.muted,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: trackHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: FractionallySizedBox(
                    alignment: Alignment.bottomCenter,
                    heightFactor: fill,
                    child: Container(
                      decoration: BoxDecoration(
                        color: rating.foreground,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 날짜는 일(日)만. 7칸에 "8/27"을 넣으면 글자가 줄어들어 오히려 안 읽힌다.
          Text(
            '${day.date.day}',
            style: AppText.badgeSmall.copyWith(
              color: isToday ? AppColors.ink : AppColors.muted,
              fontSize: 12,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
