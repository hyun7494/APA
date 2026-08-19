import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/models/catch_record.dart';
import 'package:fishing_app/services/api_client.dart';
import 'package:fishing_app/services/photo_picker.dart';
import 'package:fishing_app/services/remote_fishing_repository.dart';

/// 요청을 붙잡아 두고 고정 응답을 돌려주는 어댑터.
class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? request;
  final _body = BytesBuilder();

  String get bodyText => utf8.decode(_body.takeBytes(), allowMalformed: true);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        _body.add(chunk);
      }
    }
    return ResponseBody.fromString(
      jsonEncode({
        'record': {
          'id': 1,
          'speciesId': 6,
          'speciesName': '부시리',
          'photoUrl': '/fishing/me/photos/x.jpg',
          'lengthCm': 62.5,
          'caughtAt': '2026-08-19T10:00:00',
        },
        'firstCatch': true,
        'ownedCount': 17,
        'totalCount': 36,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // flutter_secure_storage 는 플랫폼 채널을 탄다. ApiClient 인터셉터가
    // 요청마다 토큰을 읽으므로 대역을 물려주지 않으면 여기서 멈춘다.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => call.method == 'read' ? null : <String, String>{},
        );
  });

  test('조과 등록은 사진 파트에 실제 이미지 타입을 선언한다', () async {
    final adapter = _CapturingAdapter();
    final client = ApiClient();
    client.dio.httpClientAdapter = adapter;

    await RemoteFishingRepository(client).registerCatch(
      CatchDraft(
        speciesId: 6,
        lengthCm: 62.5,
        caughtAt: DateTime(2026, 8, 19, 10),
        photo: PickedPhoto(
          // ★ 확장자 없는 파일명이 이 검사의 핵심이다.
          //   Dio 는 파일명 확장자를 보고 Content-Type 을 알아서 채우지만,
          //   확장자가 없으면 application/octet-stream 으로 떨어진다. 그러면
          //   서버는 선언된 타입만 보므로 멀쩡한 PNG 도 400 이 된다.
          //   카메라가 만든 임시 파일명에 확장자가 없는 경우가 있다.
          bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
          name: 'IMG_0421',
          mimeType: 'image/png',
        ),
        spotName: '기장 학리',
        memo: '들물에 입질',
      ),
    );

    final sent = adapter.request!;
    expect(sent.method, 'POST');
    expect(sent.path, '/fishing/me/catches');
    expect(
      sent.headers[Headers.contentTypeHeader].toString(),
      contains('multipart/form-data'),
      reason: 'BaseOptions 의 application/json 이 남으면 서버가 폼을 파싱하지 못한다',
    );

    final body = adapter.bodyText;

    expect(body.toLowerCase(), contains('content-type: image/png'));
    expect(body, isNot(contains('application/octet-stream')));
    expect(body, contains('filename="IMG_0421"'));

    // 한글 필드가 그대로 실려야 한다 (6-G 검증에서 서버 쪽은 확인됨)
    expect(body, contains('기장 학리'));
    expect(body, contains('들물에 입질'));
    expect(body, contains('62.5'));
  });

  test('사진이 없으면 photo 파트를 아예 넣지 않는다', () async {
    final adapter = _CapturingAdapter();
    final client = ApiClient();
    client.dio.httpClientAdapter = adapter;

    await RemoteFishingRepository(client).registerCatch(
      CatchDraft(speciesId: 6, lengthCm: 30, caughtAt: DateTime(2026, 8, 19)),
    );

    // 빈 파트를 보내면 서버가 "사진 파일이 비어 있습니다" 로 400 을 낸다.
    // 보내지 않으면 사진 없는 기록으로 통과한다 — 둘은 다른 결과다.
    expect(adapter.bodyText, isNot(contains('name="photo"')));
  });
}
