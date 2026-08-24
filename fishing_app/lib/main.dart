import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'router/app_router.dart';
import 'services/social_sign_in.dart';
import 'services/theme_controller.dart';
import 'theme/app_theme.dart';
import 'theme/theme_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 홈 화면의 "6월 22일 (월)" 같은 한국어 날짜 포맷을 쓰기 위해 필요하다.
  await initializeDateFormatting('ko_KR');

  // 카카오 SDK 는 로그인 버튼을 누를 때가 아니라 **앱 시작 시** 초기화해야 한다.
  // 키가 비어 있어도 초기화 자체는 통과하고, 실제 로그인 시점에 카카오가 거절한다 —
  // 키 없이도 나머지 화면은 전부 동작해야 하므로 여기서 막지 않는다.
  KakaoSdk.init(
    nativeAppKey: kakaoNativeAppKey,
    javaScriptAppKey: kakaoJavaScriptKey,
  );

  // 첫 프레임 전에 읽어야 라이트로 떴다가 다크로 바뀌는 깜빡임이 없다.
  ThemeModeStore.initial = await ThemeModeStore.load();
  // 팔레트도 여기서 미리 맞춰 둔다. 안 하면 첫 프레임을 라이트로 그린 뒤
  // 트리 전체를 한 번 더 다시 그리게 된다.
  AppColors.use(
    ThemeScope.resolve(
      ThemeModeStore.initial,
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    ),
  );

  runApp(const ProviderScope(child: FishingApp()));
}

class FishingApp extends StatefulWidget {
  const FishingApp({super.key});

  @override
  State<FishingApp> createState() => _FishingAppState();
}

class _FishingAppState extends State<FishingApp> {
  /// 라우터는 이 트리가 소유한다 — 전역으로 공유하면 트리가 재생성될 때
  /// 이미 dispose된 네비게이터를 다시 붙이게 된다.
  late final _router = createAppRouter();

  @override
  Widget build(BuildContext context) {
    // 다크/라이트는 `darkTheme`+`themeMode` 가 아니라 여기서 한 벌만 골라
    // 넘긴다 — 색 이름(`AppColors.ink`)이 전역이라, 두 벌을 동시에 짜면
    // 둘 중 한쪽이 반대 팔레트로 만들어진다.
    return ThemeScope(
      builder: (context, theme) => MaterialApp.router(
        title: '낚시출조',
        debugShowCheckedModeBanner: false,
        theme: theme,
        routerConfig: _router,
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [Locale('ko', 'KR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
