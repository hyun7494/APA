import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/post.dart';
import '../services/login_gate.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/authed_photo.dart';
import '../widgets/async_view.dart';
import '../widgets/pill_chip.dart';
import '../widgets/reveal.dart';

/// 게시판 — 전체/조황/자유/질문 탭 + 글 카드 목록.
///
/// 목록과 상세 읽기는 비로그인도 된다 (기획서 5-5). **글쓰기·댓글·좋아요만 로그인이
/// 필요하다** — 셋 다 누가 했는지가 남기 때문이고, 그 판정은 [requireLogin] 이 한다.
/// 신고는 아직 없다 (계약서 3-8).
class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedBoardTabProvider);
    final posts = ref.watch(postsProvider);

    void selectTab(PostCategory? category) =>
        ref.read(selectedBoardTabProvider.notifier).state = category;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Reveal(
            child: ScreenHeader(
              title: '게시판',
              actions: [
                HeaderButton(
                  label: '글쓰기',
                  icon: AppIcon.pencil,
                  filled: true,
                  onPressed: () => requireLogin(
                    context,
                    ref,
                    destination: '/board/new',
                    reason: '글을 쓰려면 로그인이 필요해요.\n작성자 이름이 함께 올라갑니다.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Reveal(
            index: 1,
            child: ChipRow(
              children: [
                SquareChip(
                  label: '전체',
                  selected: selected == null,
                  onTap: () => selectTab(null),
                ),
                for (final category in PostCategory.values)
                  SquareChip(
                    label: category.label,
                    selected: selected == category,
                    onTap: () => selectTab(category),
                  ),
              ],
            ),
          ),
          Expanded(
            child: posts.when(
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.screen, 24, 22, 0),
                child: LoadingView(height: 240, lines: 6),
              ),
              error: (e, _) =>
                  ErrorView(message: '글을 불러오지 못했어요', error: e, height: 240),
              data: (list) {
                if (list.isEmpty) {
                  return const ErrorView(message: '아직 글이 없어요', height: 240);
                }
                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    14,
                    AppSpacing.screen,
                    AppSpacing.navClearance,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.gap),
                  itemBuilder: (_, i) =>
                      Reveal(index: i + 2, child: _PostCard(post: list[i])),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final Post post;

  /// 카테고리마다 성격이 다른 아이콘을 붙여, 태그 색만으로 구분하던 것보다
  /// 스캔이 빨라지게 한다.
  static AppIcon _iconFor(PostCategory category) => switch (category) {
    PostCategory.catchReport => AppIcon.fish,
    PostCategory.free => AppIcon.chat,
    PostCategory.question => AppIcon.info,
  };

  @override
  Widget build(BuildContext context) {
    final color = post.category.color;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 14),
      // 누르면 본문 전체와 댓글이 있는 상세로 간다. 읽기는 로그인이 필요 없다.
      onTap: () => context.go('/board/${post.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: color.withValues(alpha: 0.22)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LineIcon(
                      _iconFor(post.category),
                      size: 12,
                      color: color,
                      stroke: 1.4,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      post.category.label,
                      style: AppText.badge.copyWith(color: color),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  // 지역을 안 고르고 쓴 글은 라벨을 뺀다. '전체' 는 지명이 아니라
                  // 옆에 붙은 '남해'·'서해' 와 같은 자리에 오면 읽히지 않는다.
                  [?post.regionName, post.relativeTime].join(' · '),
                  style: AppText.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 사진이 있으면 카드에 사진 자체가 뜬다. 아이콘은 사진을 못 보던
              // 시절의 대체물이라, 둘을 같이 두면 같은 말을 두 번 한다.
              if (post.hasImage && post.photoUrl == null) ...[
                const SizedBox(width: 6),
                LineIcon(
                  AppIcon.image,
                  size: 13,
                  color: AppColors.faint,
                  stroke: 1.3,
                ),
              ],
            ],
          ),
          if (post.photoUrl != null) ...[
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.tile),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                // 목록은 320px 판으로 충분하다 — 카드 폭이 그보다 작다.
                child: AuthedPhoto(path: post.photoUrl, thumb: true),
              ),
            ),
          ],
          const SizedBox(height: 13),
          Text(post.title, style: AppText.sectionTitle),
          const SizedBox(height: 6),
          Text(
            post.summary,
            style: AppText.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 11),
          Row(
            children: [
              _Stat(
                icon: AppIcon.heart,
                value: post.likeCount,
                active: post.likedByMe,
              ),
              const SizedBox(width: 16),
              _Stat(icon: AppIcon.chat, value: post.commentCount),
              const Spacer(),
              Text(post.authorNickname, style: AppText.caption),
            ],
          ),
        ],
      ),
    );
  }

}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, this.active = false});

  final AppIcon icon;
  final int value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accentDark : AppColors.faint;

    return Row(
      children: [
        LineIcon(icon, size: 14, color: color, stroke: 1.4),
        const SizedBox(width: 6),
        Text('$value', style: AppText.badgeSmall.copyWith(color: color)),
      ],
    );
  }
}
