import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
import '../widgets/authed_photo.dart';
import '../widgets/collection_progress.dart';
import '../widgets/press_scale.dart';
import '../widgets/rating_badge.dart';
import '../widgets/reveal.dart';

/// 홈 — 비대칭 벤토 구성.
///
/// 낚시 지수를 화면을 지배하는 히어로 한 장으로 두고, 그 아래를 5:4로
/// 어긋나게 나눈다. Rev 2에서 왼쪽 큰 판이 운세에서 **도감 진행도**로 바뀌었다
/// — 운세 점수는 매일 리셋되지만 도감은 쌓이기만 해서 복귀 동기가 더 강하다.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// 요일 라벨을 직접 만든다 — intl 로케일 초기화 상태에 의존하지 않는다.
  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredSpotProvider);
    final summary = ref.watch(collectionSummaryProvider);
    final recent = ref.watch(recentCatchPostsProvider);
    final now = DateTime.now();

    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          18,
          AppSpacing.screen,
          AppSpacing.navClearance,
        ),
        children: [
          Reveal(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('M월 d일').format(now)} '
                  '${_weekdays[now.weekday - 1]}',
                  style: AppText.caption,
                ),
                const SizedBox(height: 10),
                Text('오늘 출조,\n어떠세요?', style: AppText.pageTitle),
              ],
            ),
          ),
          const SizedBox(height: 22),

          Reveal(index: 1, child: _IndexHero(spot: featured)),
          const SizedBox(height: AppSpacing.gap),

          // 벤토 — 왼쪽 도감 진행도(5) : 오른쪽 물때·일출(4)
          Reveal(
            index: 2,
            child: SizedBox(
              // "5물 · 만조 13:20"은 좁은 타일에서 두 줄로 감긴다.
              // 두 줄이 들어갈 높이를 확보해야 폰트가 바뀌어도 안 넘친다.
              height: 196,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: _FieldGuideTile(summary: summary)),
                  const SizedBox(width: AppSpacing.gap),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        Expanded(
                          child: IconValueCard(
                            icon: AppIcon.moon,
                            iconBg: AppColors.chipBlueBg,
                            iconFg: AppColors.chipBlueFg,
                            label: '물때',
                            value: featured.valueOrNull?.tideInfo ?? '—',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.gap),
                        Expanded(
                          child: IconValueCard(
                            icon: AppIcon.sunrise,
                            iconBg: AppColors.chipAmberBg,
                            iconFg: AppColors.chipAmberFg,
                            label: '일출·일몰',
                            value: featured.valueOrNull?.sunriseSunset ?? '—',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          const Reveal(
            index: 3,
            child: NoticeLine(
              text: '참고용 정보이며 실제 출조 여부는 현장 상황을 확인하세요.',
            ),
          ),

          // 최근 조황 — 남들이 오늘 뭘 잡았는지. 지수가 "나가도 되나"라면 이쪽은
          // "나갔더니 어땠나"다. 둘이 붙어 있어야 홈이 하루를 다 설명한다.
          //
          // ⚠️ 글이 없을 수 있다. 그때는 섹션째 감춘다 — 빈 카드를 두면 홈이
          //    더 허전해 보이고, 초대 문구를 띄우면 글쓰기를 강요하는 꼴이 된다.
          ...switch (recent.valueOrNull) {
            null || [] => const <Widget>[],
            final posts => [
              const SizedBox(height: AppSpacing.section),
              Reveal(
                index: 4,
                child: SectionLabel(
                  label: '최근 조황',
                  padded: false,
                  trailing: PressScale(
                    onTap: () => context.go('/board'),
                    scale: 0.94,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('더보기', style: AppText.caption),
                        const SizedBox(width: 2),
                        LineIcon(
                          AppIcon.chevronRight,
                          size: 13,
                          color: AppColors.faint,
                          stroke: 1.5,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < posts.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.gap),
                Reveal(index: 5 + i, child: _RecentPostRow(post: posts[i])),
              ],
            ],
          },
        ],
      ),
    );
  }
}

/// 최근 조황 한 줄.
///
/// 게시판 카드보다 납작하다 — 홈에서는 본문 요약까지 읽히려는 게 아니라
/// "뭐가 올라왔나"만 훑고 넘어가는 자리다.
class _RecentPostRow extends StatelessWidget {
  const _RecentPostRow({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppRadius.cardTight,
      padding: const EdgeInsets.all(10),
      onTap: () => context.go('/board/${post.id}'),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.thumb),
              // 게시글 사진은 공개 경로지만 받아오는 길은 같다. 사진이 없으면
              // 줄무늬로 물러선다 — 조황 글에 사진이 없는 것도 정상이다.
              child: AuthedPhoto(path: post.photoUrl, stripe: 5, thumb: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  post.title,
                  style: AppText.tileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${post.regionName ?? '전체'} · ${post.relativeTime}',
                  style: AppText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          LineIcon(
            AppIcon.chevronRight,
            size: 14,
            color: AppColors.faint,
            stroke: 1.5,
          ),
        ],
      ),
    );
  }
}

/// 홈 히어로 — 대표 포인트의 낚시 지수.
class _IndexHero extends StatelessWidget {
  const _IndexHero({required this.spot});

  final AsyncValue<Spot?> spot;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: spot.when(
        loading: () => const LoadingView(height: 250, lines: 5),
        error: (e, _) =>
            ErrorView(message: '지수를 불러오지 못했어요', error: e, height: 250),
        data: (s) {
          if (s == null) {
            return const ErrorView(message: '표시할 포인트가 없어요', height: 250);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '오늘의 낚시지수',
                      style: AppText.cardLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${s.name} · ${s.regionName}', style: AppText.caption),
                ],
              ),
              const SizedBox(height: 16),
              // 링 게이지를 뺐다. 등급 글자 자체가 화면에서 제일 큰 요소이고,
              // 4점 만점 수치는 그 옆 알약이 받는다.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      s.rating.label,
                      style: AppText.ratingHuge.copyWith(
                        color: s.rating.foreground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: RatingScoreBadge(rating: s.rating),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(s.comment, style: AppText.body),
              const SizedBox(height: 20),
              const CardDivider(),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: MetricColumn(
                      icon: AppIcon.thermometer,
                      label: '수온',
                      value: s.waterTemp.toStringAsFixed(1),
                      unit: '℃',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricColumn(
                      icon: AppIcon.swell,
                      label: '파고',
                      value: s.waveHeight.toStringAsFixed(1),
                      unit: 'm',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricColumn(
                      icon: AppIcon.wind,
                      label: '풍속',
                      value: s.windSpeed.toStringAsFixed(1),
                      unit: '㎧',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: '지수 자세히 보기',
                onPressed: () => context.go('/score/${s.id}'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 벤토 왼쪽 — 내 도감 진행도.
class _FieldGuideTile extends StatelessWidget {
  const _FieldGuideTile({required this.summary});

  final AsyncValue<CollectionSummary> summary;

  @override
  Widget build(BuildContext context) {
    final data = summary.valueOrNull;

    return AppCard(
      onTap: () => context.go('/collection'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '내 도감',
                  style: AppText.cardLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              LineIcon(
                AppIcon.book,
                size: 16,
                color: AppColors.accent,
                stroke: 1.4,
              ),
            ],
          ),
          const Spacer(),
          // 큰 수치 + 분모는 폰트 폭에 민감해서 넘치기 쉽다. 넘칠 때만
          // 줄여 맞춘다 — 자르거나 줄바꿈하면 계기처럼 안 읽힌다.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  data == null ? '—' : '${data.owned}',
                  style: AppText.numberHuge,
                ),
                const SizedBox(width: 5),
                Text(
                  data == null ? '' : '/${data.total}',
                  style: AppText.numberMedium.copyWith(
                    fontSize: 15,
                    color: AppColors.faint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (data != null)
            CollectionProgressBar(summary: data, height: 8)
          else
            const SizedBox(height: 8),
          const SizedBox(height: 12),
          Text(
            data == null
                ? '도감을 불러오는 중'
                : data.newThisMonth > 0
                ? '이번 달 새로 ${data.newThisMonth}종 등록'
                : '이번 달 새 등록이 없어요',
            style: AppText.rowLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text('도감 열기', style: AppText.caption),
              const SizedBox(width: 4),
              LineIcon(
                AppIcon.chevronRight,
                size: 11,
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

