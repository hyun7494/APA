import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/post.dart';
import '../services/fishing_repository.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/pill_chip.dart';
import '../widgets/reveal.dart';

/// 글쓰기 (계약서 3-8).
///
/// 받는 것은 셋뿐이다 — 분류·제목·내용. **사진 첨부는 아직 없다**: 서버가
/// `hasImage` 를 false 로 고정해 두었고, 게시판 카드도 이미지를 그리지 않는다.
/// 붙이려면 조과 등록의 사진 파이프라인을 재사용하면 된다.
///
/// 여기까지 왔다는 것은 로그인이 끝났다는 뜻이다 — 관문은 [requireLogin] 이
/// 게시판 화면에서 이미 통과시켰다. 그래도 서버는 토큰을 다시 확인한다.
class PostNewScreen extends ConsumerStatefulWidget {
  const PostNewScreen({super.key});

  @override
  ConsumerState<PostNewScreen> createState() => _PostNewScreenState();
}

class _PostNewScreenState extends ConsumerState<PostNewScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();

  PostCategory _category = PostCategory.catchReport;
  bool _saving = false;

  /// 서버 `BoardService` 와 같은 값이다.
  static const _titleMax = 255;
  static const _contentMax = 5000;

  @override
  void initState() {
    super.initState();
    // 저장 버튼의 활성 여부가 입력에 따라 바뀐다.
    _title.addListener(_onChanged);
    _content.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_saving &&
      _title.text.trim().isNotEmpty &&
      _content.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const LineIcon(AppIcon.chevronLeft, size: 22),
          onPressed: _saving ? null : () => context.pop(),
        ),
        title: const Text('글쓰기'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.screen),
            child: Center(
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Opacity(
                      opacity: _canSubmit ? 1 : 0.35,
                      child: HeaderButton(
                        label: '등록',
                        onPressed: _canSubmit ? _submit : () {},
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            8,
            AppSpacing.screen,
            32,
          ),
          children: [
            Reveal(child: Text('분류', style: AppText.overline)),
            const SizedBox(height: 10),
            Reveal(
              child: ChipRow(
                children: [
                  for (final category in PostCategory.values)
                    SquareChip(
                      label: category.label,
                      selected: _category == category,
                      // 저장 중에는 분류를 못 바꾸게 한다 — 이미 보낸 값과
                      // 화면이 어긋나면 어느 쪽으로 올라갔는지 알 수 없다.
                      onTap: () {
                        if (_saving) return;
                        setState(() => _category = category);
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            Reveal(index: 1, child: Text('제목', style: AppText.overline)),
            const SizedBox(height: 8),
            Reveal(
              index: 1,
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                radius: AppRadius.cardTight,
                child: TextField(
                  controller: _title,
                  enabled: !_saving,
                  maxLength: _titleMax,
                  cursorColor: AppColors.accent,
                  style: AppText.infoValue,
                  decoration: InputDecoration(
                    hintText: '무슨 이야기인가요?',
                    hintStyle: AppText.infoValue.copyWith(
                      color: AppColors.faint,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    // 제목 255자는 넘길 일이 없다. 카운터가 있으면 시선만 끈다.
                    counterText: '',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Reveal(index: 2, child: Text('내용', style: AppText.overline)),
            const SizedBox(height: 8),
            Reveal(
              index: 2,
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                radius: AppRadius.cardTight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextField(
                      controller: _content,
                      enabled: !_saving,
                      maxLines: null,
                      minLines: 8,
                      maxLength: _contentMax,
                      cursorColor: AppColors.accent,
                      style: AppText.bodySmall.copyWith(color: AppColors.body),
                      decoration: InputDecoration(
                        hintText: '물때, 채비, 그날의 상황처럼\n다른 사람에게 도움이 될 것들',
                        hintStyle: AppText.bodySmall.copyWith(
                          color: AppColors.faint,
                        ),
                        isDense: true,
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                    Text(
                      '${_content.text.length} / $_contentMax',
                      style: AppText.caption.copyWith(color: AppColors.disabled),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await ref.read(fishingRepositoryProvider).createPost(
        category: _category,
        title: _title.text.trim(),
        content: _content.text.trim(),
      );
      if (!mounted) return;

      // 방금 쓴 글이 목록에 보여야 한다. 서버가 준 글 하나를 끼워 넣는 대신
      // 목록을 다시 받는다 — 정렬·요약·집계를 서버가 하므로 그 결과가 정답이다.
      ref.invalidate(postsProvider);
      // 쓴 분류의 탭으로 옮겨 준다. 전체 탭이면 그대로 둔다.
      final selected = ref.read(selectedBoardTabProvider);
      if (selected != null && selected != _category) {
        ref.read(selectedBoardTabProvider.notifier).state = _category;
      }

      context.pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('글을 올렸어요')));
    } on PostSubmitException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('글을 올리지 못했어요 ($e)');
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
