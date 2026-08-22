import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/widgets/authed_photo.dart';
import 'package:fishing_app/widgets/photo_placeholder.dart';

/// 1x1 투명 PNG. 디코딩까지 되는 진짜 이미지다.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: SizedBox(width: 80, height: 80, child: child)),
    ),
  );
}

void main() {
  testWidgets('★ 사진 주소가 없으면 네트워크를 건드리지 않고 줄무늬를 그린다', (tester) async {
    // 사진 없이 등록한 기록과 시드 데이터가 이 경우다. 여기서 요청이 나가면
    // 비로그인 사용자의 도감이 401 을 줄줄이 만든다.
    await _pump(tester, const AuthedPhoto(path: null));
    await tester.pump();

    expect(find.byType(PhotoPlaceholder), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('빈 문자열도 마찬가지다', (tester) async {
    await _pump(tester, const AuthedPhoto(path: ''));
    await tester.pump();

    expect(find.byType(PhotoPlaceholder), findsOneWidget);
  });

  testWidgets('★ 바이트를 받으면 사진을 그린다', (tester) async {
    const path = '/fishing/me/photos/abc.jpg';
    await _pump(
      tester,
      const AuthedPhoto(path: path),
      overrides: [
        photoBytesProvider(path).overrideWith((ref) async => _png),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(PhotoPlaceholder), findsNothing);
  });

  testWidgets('★ 못 받으면 오류가 아니라 줄무늬로 돌아간다', (tester) async {
    // 사진 한 장 때문에 도감 전체가 오류 화면이 되면 안 된다.
    const path = '/fishing/me/photos/gone.jpg';
    await _pump(
      tester,
      const AuthedPhoto(path: path),
      overrides: [
        photoBytesProvider(path).overrideWith((ref) async => null),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(PhotoPlaceholder), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('★ thumb 를 켜면 320px 판을 받는다 (그리드가 원본을 36장 받지 않도록)', (tester) async {
    const path = '/fishing/me/photos/abc.jpg';
    var requested = '';

    await _pump(
      tester,
      const AuthedPhoto(path: path, thumb: true),
      overrides: [
        // family 키가 곧 요청 주소다. 어느 판을 받는지는 그 키로만 드러난다.
        photoBytesProvider.overrideWith((ref, key) async {
          requested = key;
          return _png;
        }),
      ],
    );
    await tester.pumpAndSettle();

    expect(requested, '$path?thumb=true');
  });
}
