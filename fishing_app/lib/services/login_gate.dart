import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_controller.dart';

/// 로그인이 필요한 자리에서 부르는 관문.
///
/// **로그인해 있으면 그냥 [destination] 으로 보낸다.** 아니면 로그인 화면으로 보내되,
/// 왜 필요한지와 로그인 후 돌아갈 곳을 함께 넘긴다.
///
/// 화면마다 `if (!loggedIn) context.go('/login')` 을 흩어 두면 이유 문구를 빠뜨리거나
/// 돌아갈 경로를 잘못 넣는 자리가 반드시 생긴다. 한 군데로 모은다.
Future<void> requireLogin(
  BuildContext context,
  WidgetRef ref, {
  required String destination,
  required String reason,
}) async {
  // ⚠️ 캐시된 `AuthState` 를 보면 안 된다. 저장된 토큰을 읽어오는 복원은 비동기라,
  //    앱을 켜자마자 누르면 아직 끝나지 않았을 수 있다 — 그러면 **로그인해 둔
  //    사용자가 로그인 화면으로 튕긴다.** 저장소에 직접 묻는다.
  final loggedIn = await ref.read(authRepositoryProvider).isLoggedIn;
  if (!context.mounted) return;

  if (loggedIn) {
    context.go(destination);
    return;
  }
  // ⚠️ `cameFrom` 을 함께 넘긴다. 로그인을 건너뛴 사람은 **왔던 자리로 돌아가야** 하는데,
  //    `destination` 은 로그인이 필요해서 막힌 화면이라 그리로 보내면 관문을 통과시킨 셈이 된다
  //    (`PostNewScreen` 주석: "여기까지 왔다는 것은 로그인이 끝났다는 뜻이다").
  context.go('/login', extra: <String, String?>{
    'reason': reason,
    'redirectTo': destination,
    'cameFrom': GoRouterState.of(context).uri.toString(),
  });
}
