import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../services/fishing_repository.dart';
import '../services/photo_picker.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
import '../widgets/authed_photo.dart';
import '../widgets/photo_source_sheet.dart';
import '../widgets/press_scale.dart';
import '../widgets/pill_chip.dart';
import '../widgets/reveal.dart';

/// 글쓰기 (계약서 3-8).
///
/// 받는 것은 넷이다 — 사진·분류·제목·내용. **사진은 선택**이다: 조황 글에는 사진이
/// 본체지만 질문 글에까지 강요할 이유가 없다.
///
/// 여기까지 왔다는 것은 로그인이 끝났다는 뜻이다 — 관문은 [requireLogin] 이
/// 게시판 화면에서 이미 통과시켰다. 그래도 서버는 토큰을 다시 확인한다.
class PostNewScreen extends ConsumerStatefulWidget {
  const PostNewScreen({super.key, this.postId});

  /// 주면 **고치기**, 없으면 새 글. 화면이 거의 같아서 하나로 둔다 —
  /// 따로 만들면 분류 칩·글자수 제한 같은 것이 두 곳에서 어긋난다.
  final int? postId;

  bool get isEdit => postId != null;

  @override
  ConsumerState<PostNewScreen> createState() => _PostNewScreenState();
}

class _PostNewScreenState extends ConsumerState<PostNewScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();

  PostCategory _category = PostCategory.catchReport;
  bool _saving = false;

  /// 고치기일 때 기존 글을 한 번만 채워 넣기 위한 표시.
  bool _loaded = false;

  /// 새로 고른 사진. null 이면 **건드리지 않는다** — 고치기에서 이 값이 null 이면
  /// 서버가 기존 사진을 그대로 둔다.
  PickedPhoto? _photo;

  /// 고치기 화면에서 원래 붙어 있던 사진. 미리보기에만 쓴다.
  String? _existingPhotoUrl;

  /// 서버 `BoardService` 와 같은 값이다. 제목 컬럼이 VARCHAR(100) 이라 여기가 더 크면
  /// 통과시켜 놓고 서버에서 400 을 받는다.
  static const _titleMax = 100;
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

  /// 고치기 화면은 기존 글로 시작한다. **한 번만** 채운다 —
  /// 다시 채우면 사용자가 고치던 내용을 서버 값이 덮어쓴다.
  void _fillOnce(PostDetail post) {
    if (_loaded) return;
    _loaded = true;
    _title.text = post.title;
    _content.text = post.content;
    _category = post.category;
    _existingPhotoUrl = post.photoUrl;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEdit) {
      final existing = ref.watch(postDetailProvider(widget.postId!)).valueOrNull;
      if (existing == null) {
        return const Center(child: CircularProgressIndicator());
      }
      _fillOnce(existing);
    }

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
            label: widget.isEdit ? '글로 돌아가기' : '게시판으로',
            // pop 이 아니라 go 다. 이 화면은 `requireLogin` 이 go 로 열어서
            // 브랜치 스택에 쌓인 것이 없다 — pop 하면 "there is nothing to pop" 이다.
            onTap: () {
              if (_saving) return;
              context.go(widget.isEdit ? '/board/${widget.postId}' : '/board');
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
                      label: widget.isEdit ? '저장' : '등록',
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
                Reveal(
                  child: Text(
                    widget.isEdit ? '글 수정' : '글쓰기',
                    style: AppText.screenTitle,
                  ),
                ),
                const SizedBox(height: 22),

                Reveal(child: Text('사진', style: AppText.overline)),
                const SizedBox(height: 10),
                Reveal(child: _photoField()),
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
                        // 제목 100자는 넘길 일이 없다. 카운터가 있으면 시선만 끈다.
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

  /// 사진 칸. 고른 것이 있으면 그것을, 없으면 (고치기라면) 원래 사진을 보여 준다.
  ///
  /// **선택이다.** 조과 등록과 달리 글은 사진 없이도 올릴 수 있다 — 질문 글에
  /// 사진을 강요할 이유가 없다.
  Widget _photoField() {
    final picked = _photo;

    return PressScale(
      onTap: _saving ? null : _pickPhoto,
      scale: 0.99,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (picked != null)
                Image.memory(picked.bytes, fit: BoxFit.cover)
              else
                AuthedPhoto(path: _existingPhotoUrl),
              if (picked == null && _existingPhotoUrl == null)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LineIcon(
                        AppIcon.camera,
                        size: 26,
                        color: AppColors.faint,
                        stroke: 1.5,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '사진 추가 (선택)',
                        style: AppText.caption.copyWith(color: AppColors.label),
                      ),
                    ],
                  ),
                )
              else
                // 이미 사진이 있으면 "바꾸기"를 얹는다 — 눌러야 바뀐다는 것을 알려야 한다.
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.scrim,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Text(
                      '사진 바꾸기',
                      style: AppText.badgeSmall.copyWith(
                        color: AppColors.onAccent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    // 조과 등록과 같은 시트·한도·권한 안내를 쓴다.
    final picked = await pickPhotoFromSheet(context, ref, onMessage: _toast);
    if (picked == null || !mounted) return;
    setState(() => _photo = picked);
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
    // 상세도 다시 받아야 고친 내용이 보인다.
    if (widget.isEdit) ref.read(postRevisionProvider.notifier).state++;
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
