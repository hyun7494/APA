import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/profile.dart';
import '../models/species.dart';
import '../services/auth_controller.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
import '../widgets/collection_progress.dart';
import '../widgets/pill_chip.dart';
import '../widgets/reveal.dart';

/// 마이페이지 — 프로필 히어로, 통계, 즐겨찾는 지역, 메뉴.
///
/// Rev 2에서 통계 첫 칸이 **도감 진행률**로 바뀌고, 메뉴의 `띠 설정`이 빠졌다
/// (운세 전용 기능이라 운세를 되살릴 때 함께 복구한다).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const _menu = <({AppIcon icon, String label, String? route})>[
    (icon: AppIcon.book, label: '내 조과 기록', route: '/collection'),
    (icon: AppIcon.pin, label: '즐겨찾는 지역', route: null),
    // ⚠️ `알림 설정` 을 뺐다 (2026-08-25). 켜고 끌 알림이 **하나도 없다** — FCM 이
    //    앱에도 서버에도 없고, `auth.user_fcm_tokens` 는 V1 이 만들어 둔 빈 표다.
    //    아무것도 안 하는 토글을 두면 사용자는 알림이 안 오는 것을 고장으로 받아들인다.
    //    푸시를 붙일 때 이 줄을 되살릴 것.
    (icon: AppIcon.settings, label: '설정', route: '/settings'),
    (icon: AppIcon.headset, label: '고객센터', route: '/support'),
    // 로그인 상태에 따라 라벨이 바뀌는 유일한 행이다. 아래 [_authLabel] 로 갈아끼운다.
    (icon: AppIcon.logout, label: authLabel, route: null),
  ];

  /// 메뉴 목록은 const 라 여기서 상태를 반영할 수 없다. 자리 표시자를 두고
  /// 그릴 때 실제 라벨로 바꾼다.
  @visibleForTesting
  static const authLabel = '__AUTH__';

  /// 로그아웃은 되돌리기 어려운 동작이라 한 번 되묻는다. 로그인은 안 묻는다 —
  /// 어차피 다음 화면에서 취소할 수 있다.
  static Future<void> _toggleAuth(BuildContext context, WidgetRef ref) async {
    final loggedIn = ref.read(authControllerProvider).isLoggedIn;
    if (!loggedIn) {
      context.go('/login', extra: const <String, String?>{
        'redirectTo': '/profile',
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('로그아웃할까요?', style: AppText.cardLabel),
        content: Text(
          '기록은 계정에 남아 있어서 다시 로그인하면 그대로 보입니다.',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('취소', style: AppText.rowValue.copyWith(
              color: AppColors.sub,
            )),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('로그아웃', style: AppText.rowValue.copyWith(
              color: AppColors.alert,
            )),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final summary = ref.watch(collectionSummaryProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Reveal(
            child: ScreenHeader(title: '마이페이지'),
          ),
          Expanded(
            child: profile.when(
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.screen, 28, 22, 0),
                child: LoadingView(height: 300, lines: 7),
              ),
              error: (e, _) =>
                  ErrorView(message: '프로필을 불러오지 못했어요', error: e, height: 300),
              data: (p) => p == null
                  ? const _LoggedOut()
                  : _Body(
                      profile: p,
                      summary: summary.valueOrNull,
                      menu: _menu,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.profile,
    required this.summary,
    required this.menu,
  });

  final Profile profile;
  final CollectionSummary? summary;
  final List<({AppIcon icon, String label, String? route})> menu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        20,
        AppSpacing.screen,
        AppSpacing.navClearance,
      ),
      children: [
        // 프로필 히어로 — 틸 색면 하나로 화면에서 유일한 유채색을 잡는다
        Reveal(
          index: 1,
          child: AppCard(
            padding: const EdgeInsets.all(22),
            // v2는 그라디언트를 쓰지 않는다. 단색으로도 역할은 같다.
            color: AppColors.accent,
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
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
                      size: 26,
                      color: AppColors.onAccent,
                      stroke: 1.6,
                    ),
                  ),
                ),
                const SizedBox(width: 17),
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
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        profile.levelTitle.isEmpty
                            ? '조사 Lv.${profile.level}'
                            : profile.levelTitle,
                        style: AppText.rowLabel.copyWith(
                          color: AppColors.onAccent.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.gap),

        // 도감 진행률 — Rev 2에서 통계의 머리 자리를 차지한다
        Reveal(
          index: 2,
          child: AppCard(
            radius: AppRadius.cardSmall,
            padding: const EdgeInsets.all(17),
            onTap: () => context.go('/collection'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    LineIcon(
                      AppIcon.book,
                      size: 15,
                      color: AppColors.accent,
                      stroke: 1.4,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text('도감 진행률', style: AppText.rowLabel)),
                    Text(
                      summary == null ? '—' : '${summary!.owned}',
                      style: AppText.numberMedium.copyWith(fontSize: 17),
                    ),
                    Text(
                      summary == null ? '' : ' / ${summary!.total}',
                      style: AppText.numberMedium.copyWith(
                        color: AppColors.faint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (summary != null)
                  CollectionProgressBar(summary: summary!, height: 8),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.gap),

        Reveal(
          index: 3,
          child: AppCard(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _Stat(value: profile.catchCount, label: '조과 기록'),
                  const VerticalDivider(width: 1),
                  _Stat(value: profile.postCount, label: '작성 글'),
                  const VerticalDivider(width: 1),
                  _Stat(value: profile.favoriteCount, label: '즐겨찾기'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.section),

        if (profile.favoriteRegions.isNotEmpty) ...[
          Reveal(
            index: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('즐겨찾는 지역', style: AppText.sectionTitle),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final region in profile.favoriteRegions)
                      StaticPill(label: region.name),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
        ],

        // 메뉴 — 한 장의 카드 안에 행으로 묶는다. 카드를 따로 쌓으면
        // 그림자가 반복돼 화면이 시끄러워진다.
        Reveal(
          index: 5,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < menu.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Divider(),
                    ),
                  _MenuRow(
                    item: menu[i].label == ProfileScreen.authLabel
                        // 로그인 상태에 따라 이 행만 문구가 바뀐다.
                        ? (
                            icon: menu[i].icon,
                            label: ref.watch(authControllerProvider).isLoggedIn
                                ? '로그아웃'
                                : '로그인',
                            route: null,
                          )
                        : menu[i],
                    onTap: () {
                      final route = menu[i].route;
                      if (menu[i].label == ProfileScreen.authLabel) {
                        ProfileScreen._toggleAuth(context, ref);
                      } else if (route != null) {
                        context.go(route);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${menu[i].label} — 준비 중입니다'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.section),

        const Reveal(
          index: 6,
          child: NoticeLine(
            text: '도감은 검증되지 않은 개인 기록입니다. 등록한 사진은 본인만 볼 수 있습니다.',
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: AppText.numberMedium.copyWith(color: AppColors.accentDark),
          ),
          const SizedBox(height: 5),
          Text(label, style: AppText.caption),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.onTap});

  final ({AppIcon icon, String label, String? route}) item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        child: Row(
          children: [
            LineIcon(item.icon, size: 18, color: AppColors.muted, stroke: 1.4),
            const SizedBox(width: 14),
            Expanded(child: Text(item.label, style: AppText.sectionTitle)),
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

/// 비로그인 — "회원가입 없이 사용 가능" 원칙에 따라 지수·게시판·도감 열람은
/// 그대로 쓰고 마이페이지에서만 로그인을 권한다 (기획서 7장).
class _LoggedOut extends StatelessWidget {
  const _LoggedOut();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.line),
              ),
              child: Center(
                child: LineIcon(
                  AppIcon.user,
                  size: 30,
                  color: AppColors.faint,
                  stroke: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'APA 통합 계정으로 로그인하면\n도감과 조과 기록을 남길 수 있어요',
              style: AppText.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // 여기까지 와서 로그인할 방법이 없으면 안내문만 읽고 되돌아가게 된다.
            PrimaryButton(
              label: '로그인',
              onPressed: () => context.go('/login', extra: const <String, String?>{
                'redirectTo': '/profile',
              }),
            ),
          ],
        ),
      ),
    );
  }
}
