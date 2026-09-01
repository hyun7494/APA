import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
import '../widgets/pill_chip.dart';
import '../widgets/reveal.dart';

/// 남의 공개 프로필 — 게시판에서 작성자를 눌러 들어온다 (계약서 3-10).
///
/// ★ **게시판 활동만 보여 준다.** 조과 기록·도감·인증샷은 없다 — 약관 10조 2항이
/// "게시판에 따로 공개하지 않는 한 다른 회원에게 노출되지 않는다" 고 알린다.
/// 마이페이지와 화면을 나눈 이유가 그것이다: 내 것과 남의 것은 보여 줄 범위가 다르다.
///
/// 이 화면이 동호회 탭의 밑돌이다 — "이 사람 믿을 만한가" 에 답하는 자리라
/// 활동량(글·댓글·받은 좋아요)과 활동 시작 시점을 함께 둔다.
class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(publicProfileProvider(userId));

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          BackRow(
            label: '게시판으로',
            onTap: () => context.canPop() ? context.pop() : context.go('/board'),
          ),
          Expanded(
            child: profile.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.screen),
                child: LoadingView(height: 300, lines: 6),
              ),
              // 글이 하나도 없는 사람은 서버가 404 다 — 보여 줄 공개 활동이 없다.
              error: (e, _) => ErrorView(
                message: '프로필을 불러오지 못했어요',
                error: e,
                height: 300,
              ),
              data: (p) => _Body(profile: p),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        20,
        AppSpacing.screen,
        AppSpacing.navClearance,
      ),
      children: [
        Reveal(child: _hero()),
        const SizedBox(height: AppSpacing.gap),
        Reveal(index: 1, child: _stats()),
        const SizedBox(height: AppSpacing.section),

        Reveal(index: 2, child: Text('작성한 글', style: AppText.sectionTitle)),
        const SizedBox(height: 12),
        for (var i = 0; i < profile.recentPosts.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Reveal(index: 3, child: _PostRow(post: profile.recentPosts[i])),
        ],
        const SizedBox(height: AppSpacing.section),

        // 왜 조과·도감이 없는지 말해 준다. 없는 것을 그냥 비워 두면 "안 만들었나" 로
        // 읽히지만, 이건 만들지 않은 게 아니라 **보여 주지 않기로 한 것**이다.
        const Reveal(
          index: 4,
          child: NoticeLine(
            text: '조과 기록과 도감은 본인만 볼 수 있어 여기 표시되지 않습니다.',
          ),
        ),
      ],
    );
  }

  Widget _hero() {
    return AppCard(
      padding: const EdgeInsets.all(22),
      color: AppColors.accent,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.onAccent.withValues(alpha: 0.2),
              border: Border.all(
                color: AppColors.onAccent.withValues(alpha: 0.24),
              ),
            ),
            child: Center(
              child: LineIcon(
                AppIcon.user,
                size: 24,
                color: AppColors.onAccent,
                stroke: 1.6,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.nickname,
                  style: AppText.screenTitle.copyWith(
                    fontSize: 21,
                    color: AppColors.onAccent,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _since(),
                  style: AppText.rowLabel.copyWith(
                    color: AppColors.onAccent.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "2026년 8월부터 활동" — 언제부터 있었는지가 신뢰의 단서다.
  String _since() {
    if (profile.isWithdrawn) return '탈퇴한 회원입니다';
    final at = profile.firstPostAt;
    if (at == null) return '활동 기록';
    return '${at.year}년 ${at.month}월부터 활동';
  }

  Widget _stats() {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Stat(value: profile.postCount, label: '작성 글'),
            const VerticalDivider(width: 1),
            _Stat(value: profile.commentCount, label: '댓글'),
            const VerticalDivider(width: 1),
            _Stat(value: profile.likesReceived, label: '받은 좋아요'),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: AppText.numberMedium.copyWith(color: AppColors.accentDark),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppText.caption),
      ],
    );
  }
}

/// 프로필의 글 한 줄. 게시판 카드보다 납작하다 — 여기서는 "뭘 썼나" 만 훑는다.
class _PostRow extends StatelessWidget {
  const _PostRow({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/board/${post.id}'),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StaticPill(label: post.category.label),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          [?post.regionName, post.relativeTime].join(' · '),
                          style: AppText.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.title,
                    style: AppText.rowLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            LineIcon(
              AppIcon.chevronRight,
              size: 14,
              color: AppColors.faint,
              stroke: 1.5,
            ),
          ],
        ),
      ),
    );
  }
}
