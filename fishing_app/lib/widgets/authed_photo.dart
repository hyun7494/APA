import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';
import 'photo_placeholder.dart';

/// 서버에 올린 인증샷 한 장을 받아 온다.
///
/// **`Image.network` 를 쓸 수 없다.** 사진 주소가 `/fishing/me/photos/...` 라 인증이 필요한데
/// (토큰 없이 부르면 401), `Image.network` 는 Authorization 헤더를 붙이지 않는다. 그대로 쓰면
/// 올린 사진이 전부 깨져 보인다.
///
/// 그래서 [ApiClient] 의 dio 로 바이트를 받는다 — 토큰을 붙이는 인터셉터와 **401 → 재발급 →
/// 재시도** 경로를 그대로 탄다. 토큰이 만료된 채 도감을 열어도 사진이 알아서 살아난다.
///
/// `family` 라 같은 주소는 앱이 사는 동안 한 번만 받는다. 도감 그리드는 같은 표지를 스크롤하며
/// 여러 번 그리므로 이 캐시가 없으면 스크롤할 때마다 다시 받는다.
final photoBytesProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  path,
) async {
  try {
    final res = await ref
        .watch(apiClientProvider)
        .dio
        .get<List<int>>(path, options: Options(responseType: ResponseType.bytes));
    final bytes = res.data;
    return bytes == null ? null : Uint8List.fromList(bytes);
  } on DioException {
    // 사진 한 장을 못 받은 것으로 화면을 오류로 만들지 않는다 — 줄무늬 자리로 돌아간다.
    return null;
  }
});

/// 인증샷을 그릴 자리. 주소가 없거나 아직 못 받았으면 [PhotoPlaceholder] 를 그린다.
///
/// 자리는 항상 채워진다 — 로딩 중에 빈 칸이 되면 도감 그리드가 들썩인다.
class AuthedPhoto extends ConsumerWidget {
  const AuthedPhoto({
    super.key,
    required this.path,
    this.rare = false,
    this.stripe = 8,
    this.thumb = false,
  });

  /// 서버가 준 사진 경로. null 이거나 비어 있으면 줄무늬만 그린다 —
  /// 사진 없이 등록한 기록과 시드 데이터가 그렇다.
  final String? path;

  final bool rare;
  final double stripe;

  /// 서버의 320px 판을 받는다. 도감 그리드처럼 작게 여러 장 그리는 자리에 쓴다 —
  /// 36칸에 원본을 받으면 아무 이득 없이 대역폭만 쓴다.
  /// 썸네일이 없는 옛 사진은 서버가 원본으로 떨어뜨려 준다.
  final bool thumb;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = this.path;
    if (path == null || path.isEmpty) {
      return PhotoPlaceholder(rare: rare, stripe: stripe);
    }

    return ref
        .watch(photoBytesProvider(thumb ? '$path?thumb=true' : path))
        .maybeWhen(
          data: (bytes) => bytes == null
              ? PhotoPlaceholder(rare: rare, stripe: stripe)
              : Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  // 디코딩이 실패해도 자리는 지킨다.
                  errorBuilder: (_, _, _) =>
                      PhotoPlaceholder(rare: rare, stripe: stripe),
                ),
          orElse: () => PhotoPlaceholder(rare: rare, stripe: stripe),
        );
  }
}
