import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 화면 테마 설정 — 마이 > 설정에서 고른다.
///
/// 기본은 [ThemeMode.system]. 시스템을 따라가면 사용자가 아무것도 고르지
/// 않아도 밤에 알아서 어두워진다.
enum AppThemeMode {
  system('시스템 설정 따름', '기기의 다크 모드를 그대로 씁니다'),
  light('라이트', '항상 밝은 화면'),
  dark('다크', '항상 어두운 화면');

  const AppThemeMode(this.label, this.description);

  final String label;
  final String description;

  ThemeMode get themeMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  static AppThemeMode parse(String? name) => values.firstWhere(
    (m) => m.name == name,
    orElse: () => AppThemeMode.system,
  );
}

/// 고른 테마를 기기에 남긴다.
///
/// 토큰 저장에 이미 쓰고 있는 [FlutterSecureStorage] 를 그대로 쓴다. 비밀은
/// 아니지만 의존성을 하나 더 들이는 것보다 낫고, 실패해도 기본값으로 굴러가면
/// 되는 값이라 예외는 삼킨다 — 테마를 못 읽어서 앱이 안 뜨면 안 된다.
abstract final class ThemeModeStore {
  static const _key = 'app_theme_mode';

  static const _storage = FlutterSecureStorage();

  /// `main()` 이 첫 프레임 전에 채운다. 여기서 읽어 두지 않으면 앱이 라이트로
  /// 떴다가 한 프레임 뒤 다크로 바뀌는 깜빡임이 생긴다.
  static AppThemeMode initial = AppThemeMode.system;

  /// 저장소가 늦어도 **앱은 뜬다.**
  ///
  /// ★ `main()` 이 이걸 `runApp` **전에** await 한다(테마 깜빡임을 막으려고).
  /// 그래서 여기가 안 끝나면 **앱이 흰 화면으로 영영 멈추고 오류도 안 난다** —
  /// try/catch 는 예외를 잡지 멈춤을 못 잡는다. 웹 로그아웃이 정확히 그렇게 죽었다
  /// (제공자 SDK 가 초기화 전이면 안 끝나는 Future 를 돌려준다).
  ///
  /// 그래서 시간 제한을 둔다. 테마는 **못 읽어도 기본값으로 굴러가는 값**이고,
  /// 첫 프레임을 그것에 인질로 잡히면 안 된다.
  static Future<AppThemeMode> load() async {
    try {
      final saved = await _storage
          .read(key: _key)
          .timeout(const Duration(seconds: 2));
      return AppThemeMode.parse(saved);
    } catch (_) {
      // 위젯 테스트에는 플랫폼 채널이 없다 (MissingPluginException).
      // 시간 초과도 여기로 온다 — 둘 다 "그냥 기본값으로 간다" 가 답이다.
      return AppThemeMode.system;
    }
  }

  static Future<void> save(AppThemeMode mode) async {
    try {
      await _storage.write(key: _key, value: mode.name);
    } catch (_) {
      // 저장에 실패해도 이번 실행 동안은 고른 테마가 그대로 적용된다.
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, AppThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() => ThemeModeStore.initial;

  Future<void> select(AppThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    await ThemeModeStore.save(mode);
  }
}
