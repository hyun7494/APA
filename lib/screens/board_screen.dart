import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
import '../widgets/pill_chip.dart';
import '../widgets/reveal.dart';

/// 게시판 — 전체/조황/자유/질문 탭 + 글 카드 목록.
///
/// 글쓰기·좋아요는 인증이 필요해 백엔드 연동 후에 붙인다.
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
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('글쓰기는 로그인 연동 후 지원됩니다')),
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
                  '${post.regionName ?? '전체'} · ${_relativeTime(post.createdAt)}',
                  style: AppText.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (post.hasImage) ...[
                const SizedBox(width: 6),
                const LineIcon(
                  AppIcon.image,
                  size: 13,
                  color: AppColors.faint,
                  stroke: 1.3,
                ),
              ],
            ],
          ),
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

  /// "2시간 전", "어제" 같은 상대 시간.
  static String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays == 1) return '어제';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${time.month}월 ${time.day}일';
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
