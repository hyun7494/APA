import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/post.dart';
import '../services/fishing_repository.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
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
    // ⚠️ **자기 Scaffold 를 두지 않는다.** 셸(`app_router`)의 것을 쓴다 —
    //    조과 등록 화면과 같은 구조다. 여기에 Scaffold 를 하나 더 두면 스낵바가
    //    그 Scaffold 에 붙어서, 게시판으로 옮기는 순간 안내가 같이 사라진다.
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          BackRow(
            label: '게시판으로',
            // pop 이 아니라 go 다. 이 화면은 `requireLogin` 이 go 로 열어서
            // 브랜치 스택에 쌓인 것이 없다 — pop 하면 "there is nothing to pop" 이다.
            onTap: () {
              if (_saving) return;
              context.go('/board');
            },
            trailing: _saving
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
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                20,
                AppSpacing.screen,
                AppSpacing.navClearance,
              ),
              children: [
                Reveal(child: Text('글쓰기', style: AppText.screenTitle)),
                const SizedBox(height: 22),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 4,
                    ),
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
                          style: AppText.bodySmall.copyWith(
                            color: AppColors.body,
                          ),
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
                          style: AppText.caption.copyWith(
                            color: AppColors.disabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _saving = true);

    // ⚠️ try 는 **저장 호출만** 감싼다. 화면 전환까지 넣으면 이미 저장된 글을 두고
    //    "글을 올리지 못했어요"가 뜨고, 사용자는 실패한 줄 알고 다시 눌러 같은 글을
    //    두 번 올린다. 실제로 그렇게 됐었다.
    try {
      await ref
          .read(fishingRepositoryProvider)
          .createPost(
            category: _category,
            title: _title.text.trim(),
            content: _content.text.trim(),
          );
    } on PostSubmitException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message);
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('글을 올리지 못했어요 ($e)');
      return;
    }

    if (!mounted) return;

    // 여기서부터는 저장이 끝났다. 무엇이 잘못돼도 실패로 안내하지 않는다.
    //
    // 방금 쓴 글이 목록에 보여야 한다. 서버가 준 글 하나를 끼워 넣는 대신
    // 목록을 다시 받는다 — 정렬·요약·집계를 서버가 하므로 그 결과가 정답이다.
    ref.invalidate(postsProvider);
    // 쓴 분류의 탭으로 옮겨 준다. 전체 탭이면 그대로 둔다.
    final selected = ref.read(selectedBoardTabProvider);
    if (selected != null && selected != _category) {
      ref.read(selectedBoardTabProvider.notifier).state = _category;
    }

    // 메신저를 **옮기기 전에** 붙잡아 둔다. 이동한 뒤에 `ScaffoldMessenger.of(context)`
    // 를 부르면 이 화면의 context 는 이미 트리에서 빠진 뒤라 안내가 뜨지 않고,
    // 반대로 이동 전에 띄우면 화면이 바뀌면서 그 스낵바가 같이 사라진다.
    final messenger = ScaffoldMessenger.of(context);

    // pop 이 아니라 go 다 — 이 화면은 스택에 쌓여 있지 않다 (뒤로가기 주석 참고).
    context.go('/board');

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('글을 올렸어요')));
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
