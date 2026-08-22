import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/auth_controller.dart';
import '../services/fishing_repository.dart';
import '../services/login_gate.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
import '../widgets/press_scale.dart';
import '../widgets/reveal.dart';

/// 글 상세 (계약서 3-6-1).
///
/// **읽기는 비로그인도 된다** (기획서 5-5). 좋아요·댓글쓰기만 [requireLogin] 을 지나야 하고,
/// 그 판정은 누를 때 한다 — 글을 읽으러 온 사람을 문 앞에서 막을 이유가 없다.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final int postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _comment = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _comment.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(postDetailProvider(widget.postId));

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          // 글쓰기 화면과 같은 이유로 pop 이 아니라 go 다 — 스택에 쌓여 있지 않다.
          BackRow(label: '게시판으로', onTap: () => context.go('/board')),
          Expanded(
            child: detail.when(
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.screen, 24, AppSpacing.screen, 0),
                child: LoadingView(height: 320, lines: 6),
              ),
              error: (e, _) => ErrorView(
                message: '글을 불러오지 못했어요',
                error: e,
                height: 320,
              ),
              data: _body,
            ),
          ),
          if (detail.hasValue) _commentField(),
        ],
      ),
    );
  }

  Widget _body(PostDetail post) {
    final comments = ref.watch(commentsProvider(widget.postId));

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        20,
        AppSpacing.screen,
        AppSpacing.gap,
      ),
      children: [
        Reveal(child: _header(post)),
        const SizedBox(height: 18),
        Reveal(
          index: 1,
          child: AppCard(
            radius: AppRadius.cardTight,
            child: Text(post.content, style: AppText.body),
          ),
        ),
        const SizedBox(height: 14),
        Reveal(index: 2, child: _likeBar(post)),
        const SizedBox(height: AppSpacing.section),

        Reveal(index: 3, child: Text('댓글 ${post.commentCount}', style: AppText.overline)),
        const SizedBox(height: 10),
        comments.when(
          loading: () => const LoadingView(height: 90, lines: 2),
          error: (e, _) => const ErrorView(message: '댓글을 불러오지 못했어요', height: 90),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Text(
                    '아직 댓글이 없어요. 첫 댓글을 남겨보세요.',
                    style: AppText.bodySmall.copyWith(color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  children: [
                    for (final comment in list) ...[
                      _CommentTile(comment: comment, onDelete: () => _delete(comment)),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _header(PostDetail post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: post.category.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                post.category.label,
                style: AppText.badgeSmall.copyWith(color: post.category.color),
              ),
            ),
            const SizedBox(width: 8),
            Text(post.regionName ?? '전체', style: AppText.caption),
          ],
        ),
        const SizedBox(height: 12),
        Text(post.title, style: AppText.screenTitle),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(post.authorNickname, style: AppText.rowLabel),
            const SizedBox(width: 8),
            Text(
              DateFormat('M월 d일 HH:mm', 'ko_KR').format(post.createdAt),
              style: AppText.caption,
            ),
          ],
        ),
      ],
    );
  }

  /// 좋아요는 **서버가 준 수와 상태를 그대로** 그린다. 앱에서 +1 하면 그 사이 다른 사람이
  /// 누른 것이 빠져 화면과 서버가 조금씩 어긋난다.
  Widget _likeBar(PostDetail post) {
    final liked = post.likedByMe;

    return PressScale(
      onTap: () => _toggleLike(post),
      scale: 0.96,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: liked ? AppColors.accentSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: liked ? null : Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LineIcon(
              AppIcon.heart,
              size: 18,
              color: liked ? AppColors.accent : AppColors.label,
              stroke: 1.7,
            ),
            const SizedBox(width: 8),
            Text(
              '좋아요 ${post.likeCount}',
              style: AppText.tileName.copyWith(
                color: liked ? AppColors.accentDark : AppColors.label,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _commentField() {
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        10,
        AppSpacing.screen,
        // 키보드가 올라오면 그만큼 밀어 올린다. 안 그러면 입력칸이 가려진다.
        inset > 0 ? inset + 10 : AppSpacing.navClearance - 60,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.bottomBar,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _comment,
                enabled: !_sending,
                maxLength: 500,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                cursorColor: AppColors.accent,
                style: AppText.bodySmall.copyWith(color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: '댓글을 남겨보세요',
                  hintStyle: AppText.bodySmall.copyWith(color: AppColors.faint),
                  isDense: true,
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PressScale(
            onTap: _sending || _comment.text.trim().isEmpty ? null : _send,
            scale: 0.94,
            child: Opacity(
              opacity: _sending || _comment.text.trim().isEmpty ? 0.35 : 1,
              child: Container(
                width: 52,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppColors.onAccent),
                        ),
                      )
                    : Text(
                        '등록',
                        style: AppText.tileName.copyWith(color: AppColors.onAccent),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLike(PostDetail post) async {
    // 좋아요는 누구 것인지 남으므로 로그인이 필요하다. 읽기만 하러 온 사람은
    // 여기까지 오는 동안 아무것도 요구받지 않았다.
    if (!await _ensureLoggedIn('좋아요를 누르려면 로그인이 필요해요.')) return;

    try {
      await ref.read(fishingRepositoryProvider).toggleLike(post.id);
    } on PostSubmitException catch (e) {
      if (mounted) _toast(e.message);
      return;
    }
    if (!mounted) return;
    // 목록의 수도 같이 달라진다. 한 곳에서 올리면 둘 다 다시 받아온다.
    ref.read(postRevisionProvider.notifier).state++;
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    if (!await _ensureLoggedIn('댓글을 남기려면 로그인이 필요해요.')) return;

    setState(() => _sending = true);
    try {
      await ref.read(fishingRepositoryProvider).createComment(widget.postId, text);
    } on PostSubmitException catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        _toast(e.message);
      }
      return;
    }
    if (!mounted) return;

    _comment.clear();
    setState(() => _sending = false);
    ref.read(postRevisionProvider.notifier).state++;
  }

  Future<void> _delete(Comment comment) async {
    try {
      await ref.read(fishingRepositoryProvider).deleteComment(comment.id);
    } on PostSubmitException catch (e) {
      if (mounted) _toast(e.message);
      return;
    }
    if (!mounted) return;
    ref.read(postRevisionProvider.notifier).state++;
  }

  /// 로그인 화면으로 보내면 이 화면을 떠난다. 돌아올 곳을 글 상세로 지정해 둔다.
  Future<bool> _ensureLoggedIn(String reason) async {
    final loggedIn = await ref.read(authRepositoryProvider).isLoggedIn;
    if (loggedIn) return true;
    if (!mounted) return false;

    await requireLogin(
      context,
      ref,
      destination: '/board/${widget.postId}',
      reason: reason,
    );
    return false;
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.onDelete});

  final Comment comment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      radius: AppRadius.thumb,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(comment.authorNickname, style: AppText.tileName),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  DateFormat('M월 d일 HH:mm', 'ko_KR').format(comment.createdAt),
                  style: AppText.caption,
                ),
              ),
              // 남의 댓글에는 아예 안 보인다. 서버도 남의 것은 404 로 막는다.
              if (comment.mine)
                PressScale(
                  onTap: onDelete,
                  scale: 0.9,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      '삭제',
                      style: AppText.caption.copyWith(color: AppColors.muted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(comment.content, style: AppText.bodySmall.copyWith(color: AppColors.body)),
        ],
      ),
    );
  }
}
