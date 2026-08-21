import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:fishing_app/main.dart';
import 'package:fishing_app/screens/catch_success_screen.dart';
import 'package:fishing_app/services/auth_controller.dart';
import 'package:fishing_app/services/auth_repository.dart';
import 'package:fishing_app/services/photo_picker.dart';
import 'package:fishing_app/services/social_sign_in.dart';
import 'package:fishing_app/widgets/app_buttons.dart';
import 'package:fishing_app/widgets/pill_chip.dart';
import 'package:fishing_app/widgets/spot_card.dart';
import 'package:fishing_app/widgets/species_tile.dart';

/// 항상 같은 사진 한 장을 내주는 선택기.
///
/// 진짜 `image_picker` 는 플랫폼 채널을 타서 위젯 테스트에서는 응답이 오지
/// 않는다. 등록 플로우 검증은 이 대역으로 한다.
class FakePhotoPicker implements PhotoPicker {
  PhotoSource? lastSource;

  /// 1x1 투명 PNG. 디코딩까지 되는 진짜 이미지라 미리보기도 그려진다.
  static final bytes = Uint8List.fromList([
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

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    lastSource = source;
    return PickedPhoto(bytes: bytes, name: 'catch.png', mimeType: 'image/png');
  }
}

/// 네트워크도 제공자 SDK 도 없는 인증 대역.
///
/// 진짜 [RemoteAuthRepository] 는 auth-service(:8081)로 HTTP 를 보내고 그 전에
/// 카카오·구글 SDK 를 부른다. 위젯 테스트에서는 둘 다 응답이 없다.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({bool loggedIn = false}) : this._(loggedIn);

  FakeAuthRepository._(this._loggedIn);

  bool _loggedIn;
  SocialProvider? lastProvider;

  @override
  Future<AuthUser> signIn(SocialProvider provider) async {
    lastProvider = provider;
    _loggedIn = true;
    return const AuthUser(id: 7, nickname: '테스트조사');
  }

  @override
  Future<void> signOut() async => _loggedIn = false;

  @override
  Future<bool> get isLoggedIn async => _loggedIn;
}

/// 세로로 긴 화면에서 띄운다 — 상세 화면이 한 번에 다 렌더되도록.
/// (1080x4500 @3.0 = 360x1500 논리 픽셀)
Future<void> pumpApp(
  WidgetTester tester, {
  PhotoPicker? photoPicker,
  AuthRepository? auth,
}) async {
  tester.view.physicalSize = const Size(1080, 4500);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (photoPicker != null)
          photoPickerProvider.overrideWithValue(photoPicker),
        // 기본값도 대역이다. 진짜 구현은 생성되는 순간 보안 저장소 채널을 두드린다.
        authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
      ],
      child: const FishingApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// 사진 칸을 눌러 시트에서 [source] 를 고른다.
Future<void> pickPhoto(WidgetTester tester, PhotoSource source) async {
  await tester.tap(find.text('사진 추가'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(source.label));
  await tester.pumpAndSettle();
}

/// 가로 스크롤 칩을 화면 안으로 끌어온 뒤 누른다.
///
/// 칩이 뷰포트 밖이어도 캐시 범위 안이면 위젯은 이미 빌드돼 있다. 그래서
/// "존재하는가"만 보면 화면 밖 좌표를 눌러 탭이 빗나간다.
Future<void> tapChip(WidgetTester tester, String label) async {
  final chip = find.byWidgetPredicate(
    (w) => w is SquareChip && w.label.startsWith(label),
  );
  if (chip.evaluate().isEmpty) {
    await tester.dragUntilVisible(
      chip,
      find.byType(ChipRow),
      const Offset(-120, 0),
    );
  }
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  testWidgets('홈이 첫 화면으로 뜨고 하단 탭 5개가 보인다', (tester) async {
    await pumpApp(tester);

    expect(find.text('오늘 출조,\n어떠세요?'), findsOneWidget);
    // Rev 2 — 2번째 탭이 운세에서 도감으로 바뀌었다.
    for (final tab in ['지수', '도감', '홈', '게시판', '마이']) {
      expect(find.text(tab), findsOneWidget);
    }
    expect(find.text('운세'), findsNothing);
  });

  testWidgets('홈 벤토에 도감 진행도가 뜬다', (tester) async {
    await pumpApp(tester);

    expect(find.text('내 도감'), findsOneWidget);
    // 시드: 어종 36종 중 고유 16종 등록 (CatchSeed의 distinct speciesId)
    expect(find.text('16'), findsOneWidget);
    expect(find.text('/36'), findsOneWidget);
  });

  testWidgets('지수 탭 → 포인트 카드 → 상세로 이동한다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('지수'));
    await tester.pumpAndSettle();
    expect(find.text('낚시 지수'), findsOneWidget);
    expect(find.byType(SpotCard), findsNWidgets(2));

    await tester.tap(find.byType(SpotCard).first);
    await tester.pumpAndSettle();
    expect(find.text('시간대별 조황 예상'), findsOneWidget);
    expect(find.text('추천 어종'), findsOneWidget);
    expect(find.textContaining('참고용 정보이며'), findsWidgets);
  });

  testWidgets('지역 칩을 바꾸면 포인트 목록이 갱신된다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('지수'));
    await tester.pumpAndSettle();

    await tapChip(tester, '통영 사량도');
    expect(find.text('사량도 옥동'), findsOneWidget);
    expect(find.text('기장 대변항 방파제'), findsNothing);
  });

  testWidgets('도감 그리드가 등록/미등록 칸을 함께 보여준다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();

    expect(find.text('어류 도감'), findsOneWidget);
    expect(find.byType(SpeciesTile), findsWidgets);
    // 등록된 어종은 이름이 그대로, 미등록은 ??? 로 가려진다
    expect(find.text('감성돔'), findsOneWidget);
    expect(find.text('미기록'), findsWidgets);
  });

  testWidgets('도감 필터로 미등록만 추릴 수 있다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();

    await tapChip(tester, '등록');
    // 등록 필터에서는 가려진 칸이 사라진다
    expect(find.text('미기록'), findsNothing);
    expect(find.text('감성돔'), findsOneWidget);
  });

  testWidgets('어종 상세에 내 최고 기록과 포획 횟수가 뜬다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('감성돔'));
    await tester.pumpAndSettle();

    expect(find.text('내 최대'), findsOneWidget);
    expect(find.text('포획'), findsOneWidget);
    // 시드의 감성돔 최고 기록 42.5cm, 4회
    expect(find.textContaining('42.5'), findsWidgets);
    expect(find.text('MY RECORDS'), findsOneWidget);
  });

  testWidgets('★ 비로그인으로 등록을 누르면 로그인 화면으로 보낸다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HeaderButton, '등록'));
    await tester.pumpAndSettle();

    expect(find.text('기록 추가'), findsNothing, reason: '관문을 그냥 통과하면 안 된다');
    expect(find.textContaining('로그인이 필요해요'), findsOneWidget);
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.text('Google로 시작하기'), findsOneWidget);
  });

  testWidgets('★ 로그인하면 원래 가려던 화면으로 이어진다', (tester) async {
    final auth = FakeAuthRepository();
    await pumpApp(tester, auth: auth);

    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HeaderButton, '등록'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    expect(auth.lastProvider, SocialProvider.kakao);
    expect(find.text('기록 추가'), findsOneWidget, reason: '로그인 후 원래 목적지로 가야 한다');
  });

  testWidgets('도감에서 기록 추가 화면으로 들어간다', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository(loggedIn: true));

    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();

    // "등록"은 헤더 버튼과 필터 칩 양쪽에 있어 버튼 쪽으로 좁힌다
    await tester.tap(find.widgetWithText(HeaderButton, '등록'));
    await tester.pumpAndSettle();

    expect(find.text('기록 추가'), findsOneWidget);
    // 사진·어종·길이가 모두 비어 있으면 저장 버튼은 비활성이다
    expect(find.text('사진 추가'), findsOneWidget);
    expect(find.text('선택'), findsOneWidget);
    expect(find.text('기록 저장'), findsOneWidget);
  });

  testWidgets('기록을 추가하면 도감 칸이 채워지고 획득 연출로 넘어간다', (tester) async {
    final picker = FakePhotoPicker();
    await pumpApp(
      tester,
      photoPicker: picker,
      auth: FakeAuthRepository(loggedIn: true),
    );

    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HeaderButton, '등록'));
    await tester.pumpAndSettle();

    // ① 사진 — 시트에서 갤러리를 고르면 대역 선택기가 한 장 내준다
    await pickPhoto(tester, PhotoSource.gallery);
    expect(picker.lastSource, PhotoSource.gallery);
    expect(find.text('사진 추가'), findsNothing, reason: '미리보기로 바뀌어야 한다');
    expect(find.text('다시 고르기'), findsOneWidget);

    // ② 어종 — 아직 등록하지 않은 종을 고른다.
    // 부시리는 시드에 기록이 없고 그리드 첫 화면에 보여 스크롤이 필요 없다.
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('부시리'));
    await tester.pumpAndSettle();
    expect(find.text('부시리'), findsOneWidget);
    expect(find.text('선택'), findsNothing);

    // ③ 길이 — 입력란이 셋(길이·포인트·메모)이라 힌트로 길이 칸을 집는다
    final lengthField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == '0.0',
    );
    await tester.enterText(lengthField, '62.5');
    await tester.pumpAndSettle();
    expect(find.text('62.5'), findsOneWidget);

    await tester.tap(find.text('기록 저장'));
    await tester.pump();
    expect(find.text('저장 중…'), findsOneWidget);
    // 목 리포지토리의 220ms 지연을 넘긴다. pumpAndSettle은 돌아가는 애니메이션이
    // 없으면 시계를 그만큼 진행시키지 않아 등록 Future가 끝나지 않는다.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // 첫 등록이므로 획득 연출 화면으로 간다
    expect(find.text('기록 추가'), findsNothing, reason: '등록 폼에서 벗어나야 한다');
    expect(find.byType(CatchSuccessScreen), findsOneWidget);
    // 부시리는 희귀 등급이라 머리말이 희귀 문구로 갈린다
    expect(find.text('희귀 어종 획득'), findsOneWidget);
    expect(find.textContaining('칸이'), findsOneWidget);
    // 16종 → 17종
    expect(find.text('17'), findsWidgets);
  });

  testWidgets('게시판 탭 필터가 동작한다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('게시판'));
    await tester.pumpAndSettle();
    expect(find.text('오늘 학리에서 감성돔 4짜 손맛!'), findsOneWidget);

    await tester.tap(find.widgetWithText(SquareChip, '질문'));
    await tester.pumpAndSettle();
    expect(find.text('영종도 우럭 포인트 추천 부탁드려요'), findsOneWidget);
    expect(find.text('오늘 학리에서 감성돔 4짜 손맛!'), findsNothing);
  });

  testWidgets('마이페이지에 도감 진행률과 조과 통계가 보인다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();
    expect(find.text('바다러버'), findsOneWidget);
    expect(find.text('도감 진행률'), findsOneWidget);
    expect(find.text('조과 기록'), findsOneWidget);
    // 띠 설정은 Rev 2에서 빠졌다
    expect(find.text('띠 설정'), findsNothing);
  });
}
