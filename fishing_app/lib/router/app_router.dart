import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../screens/board_screen.dart';
import '../screens/catch_new_screen.dart';
import '../screens/catch_success_screen.dart';
import '../screens/collection_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/post_new_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/region_search_screen.dart';
import '../screens/score_detail_screen.dart';
import '../screens/score_list_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/species_detail_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';

/// 하단 탭 5개를 브랜치로 두고 각 탭이 자기 네비게이션 스택을 유지한다.
/// 브랜치 순서는 하단 아일랜드의 탭 배치와 같다 — 지수 / 도감 / 홈 / 게시판 / 마이.
///
/// Rev 2에서 2번 브랜치가 운세에서 도감으로 바뀌었다. `/fortune` 라우트는
/// 만들지 않는다 (기획서 5-2).
///
/// 전역 상수가 아니라 팩토리다. `GoRouter`는 내부에 네비게이터 상태를 들고
/// 살아 있어서, 하나를 여러 위젯 트리에서 돌려쓰면 앞선 트리가 dispose된 뒤
/// 재사용될 때 깨진다 (위젯 테스트가 두 번째부터 전부 실패하던 원인).
GoRouter createAppRouter() => GoRouter(
  initialLocation: '/home',
  routes: [
    // 셸 **밖**이다 — 로그인 화면에는 하단 탭이 뜨면 안 된다. 탭이 보이면 로그인을
    // 건너뛸 수 있는 것처럼 보이고, 실제로 눌렀을 때 어디로 가야 할지도 모호해진다.
    GoRoute(
      path: '/login',
      builder: (_, state) {
        final extra = state.extra is Map<String, String?>
            ? state.extra as Map<String, String?>
            : const <String, String?>{};
        return LoginScreen(
          reason: extra['reason'],
          redirectTo: extra['redirectTo'],
        );
      },
    ),
    // 로그인 화면 위에 쌓인다 (`push`) — 가입을 그만두면 로그인으로 되돌아가야 한다.
    GoRoute(
      path: '/signup',
      builder: (_, state) {
        final extra = state.extra is Map<String, String?>
            ? state.extra as Map<String, String?>
            : const <String, String?>{};
        return SignUpScreen(redirectTo: extra['redirectTo']);
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _Shell(shell: shell),
      branches: [
        // 0 · 지수 (상세·지역검색이 같은 브랜치에 쌓인다)
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/score', builder: (_, _) => const ScoreListScreen()),
            GoRoute(
              path: '/search',
              builder: (_, _) => const RegionSearchScreen(),
            ),
            GoRoute(
              path: '/score/:id',
              builder: (_, state) => ScoreDetailScreen(
                spotId: int.tryParse(state.pathParameters['id'] ?? '') ?? 1,
              ),
            ),
          ],
        ),
        // 1 · 도감 (어종 상세·조과 등록·획득 연출이 같은 브랜치에 쌓인다)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/collection',
              builder: (_, _) => const CollectionScreen(),
            ),
            GoRoute(
              path: '/collection/:speciesId',
              builder: (_, state) => SpeciesDetailScreen(
                speciesId:
                    int.tryParse(state.pathParameters['speciesId'] ?? '') ?? 1,
              ),
            ),
            GoRoute(
              path: '/catch/new',
              builder: (_, state) => CatchNewScreen(
                initialSpeciesId: int.tryParse(
                  state.uri.queryParameters['speciesId'] ?? '',
                ),
              ),
            ),
            GoRoute(
              path: '/catch/done/:speciesId',
              builder: (_, state) => CatchSuccessScreen(
                speciesId:
                    int.tryParse(state.pathParameters['speciesId'] ?? '') ?? 1,
                catchId: int.tryParse(
                  state.uri.queryParameters['catchId'] ?? '',
                ),
              ),
            ),
          ],
        ),
        // 2 · 홈
        StatefulShellBranch(
          routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())],
        ),
        // 3 · 게시판 (글쓰기가 같은 브랜치에 쌓인다)
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/board', builder: (_, _) => const BoardScreen()),
            GoRoute(
              path: '/board/new',
              builder: (_, _) => const PostNewScreen(),
            ),
            // ⚠️ `/board/new` 보다 **뒤에** 둔다. 앞에 두면 `:id` 가 "new" 를 먼저
            //    삼켜서 글쓰기 화면으로 갈 수 없다.
            GoRoute(
              path: '/board/:id',
              builder: (_, state) => PostDetailScreen(
                postId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              ),
            ),
          ],
        ),
        // 4 · 마이
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          ],
        ),
      ],
    ),
  ],
);

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemOverlay,
      child: Scaffold(
        body: shell,
        // v2 배경은 단색 회색 한 장이다 — 앰비언트 그라디언트를 걷어냈다.
        backgroundColor: AppColors.bg,
        bottomNavigationBar: BottomNavBar(
          currentIndex: shell.currentIndex,
          // 같은 탭을 다시 누르면 그 브랜치의 첫 화면으로 되돌린다.
          onSelect: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
        ),
      ),
    );
  }
}
