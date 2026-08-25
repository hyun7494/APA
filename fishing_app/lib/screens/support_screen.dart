import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
import '../widgets/press_scale.dart';
import '../widgets/reveal.dart';

/// 고객센터 — 자주 묻는 질문과 앱 정보.
///
/// ⚠️ **문의 창구는 아직 없다.** 받을 주소가 정해지지 않아서다. 여기 답이 없으면
/// 막다른 길이라는 뜻이므로, 주소가 정해지면 `문의하기` 를 이 화면에 붙일 것.
///
/// FAQ 문구는 **지금 앱이 실제로 하는 동작**만 적는다. "곧 지원 예정" 같은 말을 넣으면
/// 그 자체가 지켜야 할 약속이 되고, 이 저장소는 그런 빈 약속(사진 없는 `has_image`,
/// 댓글 없는 `comment_count`)을 이미 여러 번 걷어냈다.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  /// 근거를 함께 적어 둔다 — 답이 바뀌면 그 근거부터 확인하면 된다.
  static const _faq = <({String q, String a})>[
    (
      q: '도감은 어떻게 채워지나요?',
      a: '조과를 등록하면 그 어종 칸이 열립니다. 같은 어종을 여러 번 등록해도 칸은 하나고, '
          '그 어종의 마지막 기록을 지우면 칸은 다시 미등록으로 돌아갑니다.',
    ),
    (
      q: '등록한 사진은 누가 볼 수 있나요?',
      a: '조과 인증샷은 본인만 봅니다. 게시판에 글을 쓰면서 붙인 사진은 로그인하지 않은 '
          '사람에게도 보입니다 — 게시판은 누구나 읽을 수 있기 때문입니다.',
    ),
    (
      q: '길이를 안 적어도 등록되나요?',
      a: '됩니다. 길이는 선택입니다. 놓아준 물고기나 사진만 남기고 싶은 기록도 있으니까요. '
          '길이가 없는 기록은 도감의 최고 기록 계산에서만 빠집니다.',
    ),
    (
      q: '금지체장보다 작은 물고기도 등록되나요?',
      a: '등록됩니다. 어종과 길이가 모두 사용자가 직접 적는 값이라 앱이 위법 여부를 판정할 '
          '근거가 없습니다. 화면에 안내는 띄우지만 막지는 않습니다. 규정은 바뀔 수 있으니 '
          '해양수산부 고시를 확인해 주세요.',
    ),
    (
      q: '낚시 지수는 무엇을 보고 정하나요?',
      a: '기상청과 국립해양조사원의 공공 데이터를 모아 미리 계산해 둔 값입니다. '
          '참고용이며 실제 출조 여부는 현장 상황을 확인하세요.',
    ),
    (
      q: '로그인하지 않아도 쓸 수 있나요?',
      a: '낚시 지수 조회, 게시판 읽기, 어류 도감 열람은 로그인 없이 됩니다. '
          '조과 등록·글쓰기·댓글·좋아요·신고에만 로그인이 필요합니다.',
    ),
    (
      q: '계정은 이 앱 전용인가요?',
      a: 'APA 통합 계정입니다. 같은 계정으로 APA의 다른 앱도 쓸 수 있고, '
          '탈퇴·비밀번호 변경도 통합 계정 기준으로 처리됩니다.',
    ),
    (
      q: '글을 신고하면 어떻게 되나요?',
      a: '신고는 접수되지만 글이 바로 내려가지는 않습니다. 신고 몇 건으로 글이 사라지면 '
          '여럿이 맞춰서 멀쩡한 글을 지우는 데 쓸 수 있기 때문입니다.',
    ),
    (
      q: '화면을 어둡게 바꾸고 싶어요.',
      a: '마이 > 설정 > 화면 테마에서 라이트·다크를 고르거나 기기 설정을 따르게 할 수 있습니다.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Reveal(
            child: BackRow(
              label: '마이페이지',
              onTap: () => context.go('/profile'),
            ),
          ),
          const SizedBox(height: 14),
          const Reveal(index: 1, child: ScreenHeader(title: '고객센터')),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                22,
                AppSpacing.screen,
                AppSpacing.navClearance,
              ),
              children: [
                Reveal(
                  index: 2,
                  child: SectionLabel(label: '자주 묻는 질문', padded: false),
                ),
                const SizedBox(height: 12),
                Reveal(
                  index: 3,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < _faq.length; i++) ...[
                          if (i > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14),
                              child: Divider(),
                            ),
                          _FaqRow(item: _faq[i]),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.section),

                Reveal(
                  index: 4,
                  child: SectionLabel(label: '앱 정보', padded: false),
                ),
                const SizedBox(height: 12),
                const Reveal(index: 5, child: _AppInfoCard()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 질문 한 줄. 누르면 답이 펼쳐진다.
///
/// 답을 처음부터 다 펼쳐 두면 아홉 개가 화면을 가득 채워서 **질문을 훑을 수가 없다** —
/// 고객센터에 오는 사람은 보통 자기 질문 하나를 찾으러 온다.
class _FaqRow extends StatefulWidget {
  const _FaqRow({required this.item});

  final ({String q, String a}) item;

  @override
  State<_FaqRow> createState() => _FaqRowState();
}

class _FaqRowState extends State<_FaqRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () => setState(() => _open = !_open),
      scale: 0.995,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(widget.item.q, style: AppText.sectionTitle),
                ),
                const SizedBox(width: 10),
                // 펼침 상태를 화살표 방향으로 알린다. 아이콘을 하나 더 만들지 않고
                // 오른쪽 화살표를 돌려 쓴다.
                AnimatedRotation(
                  turns: _open ? 0.25 : 0,
                  duration: AppMotion.fast,
                  curve: AppMotion.state,
                  child: LineIcon(
                    AppIcon.chevronRight,
                    size: 15,
                    color: AppColors.faint,
                    stroke: 1.6,
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: AppMotion.fast,
              curve: AppMotion.state,
              alignment: Alignment.topCenter,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10, right: 24),
                      child: Text(widget.item.a, style: AppText.body),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// 버전은 **pubspec 에서 읽는다.** 상수로 박아 두면 배포 때마다 손으로 고쳐야 하고,
/// 그러다 한 번 빠뜨리면 사용자가 알려주는 버전과 실제가 달라 문의를 되짚을 수 없게 된다.
class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          return InfoRows(
            rows: [
              InfoRow(
                label: '앱 버전',
                // 아직 못 읽었거나 플랫폼이 안 알려줄 수 있다. 그때 `0.0.0` 같은
                // 그럴듯한 거짓말 대신 비워 둔다.
                value: info == null ? '—' : '${info.version} (${info.buildNumber})',
              ),
            ],
          );
        },
      ),
    );
  }
}
