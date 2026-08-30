import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:fishing_app/main.dart';
import 'package:fishing_app/data/mock_data.dart';
import 'package:fishing_app/models/models.dart';
import 'package:fishing_app/screens/catch_success_screen.dart';
import 'package:fishing_app/services/auth_controller.dart';
import 'package:fishing_app/services/auth_repository.dart';
import 'package:fishing_app/services/photo_picker.dart';
import 'package:fishing_app/services/fishing_repository.dart';
import 'package:fishing_app/services/location_service.dart';
import 'package:fishing_app/services/mock_fishing_repository.dart';
import 'package:fishing_app/services/providers.dart';
import 'package:fishing_app/services/social_sign_in.dart';
import 'package:fishing_app/theme/app_theme.dart';
import 'package:fishing_app/widgets/app_buttons.dart';
import 'package:fishing_app/widgets/bottom_nav_bar.dart';
import 'package:fishing_app/widgets/weekly_index_strip.dart';
import 'package:fishing_app/widgets/pill_chip.dart';
import 'package:fishing_app/widgets/press_scale.dart';
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
  FakeAuthRepository({bool loggedIn = false, bool linkRequired = false})
    : this._(loggedIn, linkRequired);

  FakeAuthRepository._(this._loggedIn, this.linkRequired);

  bool _loggedIn;
  SocialProvider? lastProvider;

  /// 소셜 로그인 때 "같은 이메일의 계정이 이미 있다"를 흉내낼지.
  /// 계정 연동 흐름을 위젯 테스트로 밟아 보려면 이 갈래가 필요하다.
  final bool linkRequired;

  String? lastEmail;
  String? lastPassword;
  String? lastNickname;
  bool linkedSocial = false;

  @override
  Future<AuthUser> signIn(SocialProvider provider) async {
    lastProvider = provider;
    if (linkRequired && !linkedSocial) {
      throw SocialLinkRequired(
        provider: provider,
        token: 'fake-token',
        email: 'hong@example.com',
      );
    }
    _loggedIn = true;
    return const AuthUser(id: 7, nickname: '테스트조사');
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    lastEmail = email;
    lastPassword = password;
    lastNickname = nickname;
    _loggedIn = true;
    return AuthUser(id: 8, nickname: nickname);
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    lastPassword = password;
    _loggedIn = true;
    return const AuthUser(id: 7, nickname: '테스트조사');
  }

  @override
  Future<AuthUser> linkSocial(SocialLinkRequired link, String password) async {
    lastPassword = password;
    linkedSocial = true;
    _loggedIn = true;
    return const AuthUser(id: 7, nickname: '테스트조사');
  }

  @override
  Future<void> signOut() async => _loggedIn = false;

  @override
  Future<bool> get isLoggedIn async => _loggedIn;
}

/// 언제나 실패하는 인증 대역. 서버가 401 을 낸 상황을 흉내낸다.
class FailingAuthRepository implements AuthRepository {
  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async => throw const AuthException('이메일 또는 비밀번호가 올바르지 않습니다');

  @override
  Future<AuthUser> signIn(SocialProvider provider) async =>
      throw const AuthException('로그인에 실패했습니다');

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async => throw const AuthException('이미 가입된 이메일입니다');

  @override
  Future<AuthUser> linkSocial(SocialLinkRequired link, String password) async =>
      throw const AuthException('비밀번호가 올바르지 않습니다');

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> get isLoggedIn async => false;
}

/// 늘 같은 자리를 내주는 위치 대역.
///
/// 진짜 [GeolocatorLocationService] 는 플랫폼 채널을 타서 위젯 테스트에서 응답이 없다
/// (사진 선택기와 같은 사정).
class FakeLocationService implements LocationService {
  FakeLocationService(this.result);

  /// 허용한 경우 — 기장 학리 근처.
  factory FakeLocationService.allowed() =>
      FakeLocationService(const LocationFound(35.24, 129.22));

  factory FakeLocationService.denied({bool forever = false}) =>
      FakeLocationService(LocationDenied(
        forever ? '위치 권한이 꺼져 있어요. 설정에서 켜주세요' : '위치 권한이 필요해요',
        openSettings: forever,
      ));

  final LocationResult result;

  @override
  Future<LocationResult> current() async => result;
}

/// 주간 예보가 비어 있는 저장소. 영종도처럼 KHOA 해역이 안 붙은 포인트를 흉내낸다.
/// 수온·파고·풍속이 없는 포인트. 새로 넣은 포인트가 첫 배치 전까지 이 상태다.
class _NoMetricsRepository extends MockFishingRepository {
  @override
  Future<List<Spot>> fetchSpots(int regionGroupId) async =>
      (await super.fetchSpots(regionGroupId)).map(_stripMetrics).toList();

  @override
  Future<Spot> fetchSpot(int id) async => _stripMetrics(await super.fetchSpot(id));
}

Spot _stripMetrics(Spot s) => Spot(
  id: s.id,
  name: s.name,
  regionGroupId: s.regionGroupId,
  regionName: s.regionName,
  rating: s.rating,
  weather: s.weather,
  tideInfo: s.tideInfo,
  sunriseSunset: s.sunriseSunset,
  comment: s.comment,
  hourlyForecast: s.hourlyForecast,
  recommendedFish: s.recommendedFish,
  updatedAt: s.updatedAt,
  weeklyIndex: s.weeklyIndex,
);

/// 어종을 '-' 하나로만 주는 먼바다 해역의 포인트 (인천항 서측·안흥항 등 17곳).
class _NoFishRepository extends MockFishingRepository {
  @override
  Future<List<Spot>> fetchSpots(int regionGroupId) async =>
      (await super.fetchSpots(regionGroupId)).map(_stripFish).toList();

  @override
  Future<Spot> fetchSpot(int id) async => _stripFish(await super.fetchSpot(id));
}

Spot _stripFish(Spot s) => Spot(
  id: s.id,
  name: s.name,
  regionGroupId: s.regionGroupId,
  regionName: s.regionName,
  rating: s.rating,
  waterTemp: s.waterTemp,
  waveHeight: s.waveHeight,
  windSpeed: s.windSpeed,
  weather: s.weather,
  tideInfo: s.tideInfo,
  sunriseSunset: s.sunriseSunset,
  comment: s.comment,
  hourlyForecast: s.hourlyForecast,
  recommendedFish: const [],
  updatedAt: s.updatedAt,
  weeklyIndex: s.weeklyIndex,
);

/// 시간대별 예보가 없는 포인트. 기상청 예보 창이 잘려 여섯 칸을 못 채운 날이 그렇다.
class _NoHourlyRepository extends MockFishingRepository {
  @override
  Future<List<Spot>> fetchSpots(int regionGroupId) async =>
      (await super.fetchSpots(regionGroupId)).map(_stripHourly).toList();

  // 상세 화면은 목록이 아니라 이쪽으로 다시 받아 온다.
  @override
  Future<Spot> fetchSpot(int id) async => _stripHourly(await super.fetchSpot(id));
}

Spot _stripHourly(Spot s) => Spot(
  id: s.id,
  name: s.name,
  regionGroupId: s.regionGroupId,
  regionName: s.regionName,
  rating: s.rating,
  waterTemp: s.waterTemp,
  waveHeight: s.waveHeight,
  windSpeed: s.windSpeed,
  weather: s.weather,
  tideInfo: s.tideInfo,
  sunriseSunset: s.sunriseSunset,
  comment: s.comment,
  hourlyForecast: const [],
  recommendedFish: s.recommendedFish,
  updatedAt: s.updatedAt,
  weeklyIndex: s.weeklyIndex,
);

class _NoWeeklyRepository extends MockFishingRepository {
  // 홈의 대표 포인트는 `featuredSpotProvider` 가 이 목록의 첫 곳으로 고른다.
  @override
  Future<List<Spot>> fetchSpots(int regionGroupId) async =>
      (await super.fetchSpots(regionGroupId)).map(_stripWeek).toList();
}

Spot _stripWeek(Spot s) => Spot(
  id: s.id,
  name: s.name,
  regionGroupId: s.regionGroupId,
  regionName: s.regionName,
  rating: s.rating,
  waterTemp: s.waterTemp,
  waveHeight: s.waveHeight,
  windSpeed: s.windSpeed,
  weather: s.weather,
  tideInfo: s.tideInfo,
  sunriseSunset: s.sunriseSunset,
  comment: s.comment,
  hourlyForecast: s.hourlyForecast,
  recommendedFish: s.recommendedFish,
  updatedAt: s.updatedAt,
);

/// 세로로 긴 화면에서 띄운다 — 상세 화면이 한 번에 다 렌더되도록.
/// (1080x4500 @3.0 = 360x1500 논리 픽셀)
Future<void> pumpApp(
  WidgetTester tester, {
  PhotoPicker? photoPicker,
  AuthRepository? auth,
  FishingRepository? repository,
  LocationService? location,
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
        if (repository != null)
          fishingRepositoryProvider.overrideWithValue(repository),
        if (location != null)
          locationServiceProvider.overrideWithValue(location),
      ],
      child: const FishingApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// 비로그인 상태에서 조과 등록을 눌러 로그인 화면까지 간다.
///
/// 로그인 화면은 직접 열 수 없다 — `redirectTo` 가 붙어야 "로그인 후 원래 목적지"까지
/// 검증할 수 있고, 그게 이 화면의 존재 이유다.
Future<void> goToLogin(WidgetTester tester) async {
  await tester.tap(find.text('도감'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(HeaderButton, '등록'));
  await tester.pumpAndSettle();
}

/// 사진 칸을 눌러 시트에서 [source] 를 고른다.
///
/// 조과 등록 스트립은 한 장이라도 고르고 나면 추가 칸 문구가 `더 넣기` 로 바뀐다 —
/// 둘 다 같은 시트를 여는 같은 자리라 여기서 흡수한다.
Future<void> pickPhoto(WidgetTester tester, PhotoSource source) async {
  final add = find.text('사진 추가');
  await tester.tap(add.evaluate().isNotEmpty ? add : find.text('더 넣기'));
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

  testWidgets('★ 홈 주간 지수는 오늘부터 7칸이고 오늘 칸이 표시된다', (tester) async {
    await pumpApp(tester);

    expect(find.text('이번 주 지수'), findsOneWidget);
    final strip = tester.widget<WeeklyIndexStrip>(find.byType(WeeklyIndexStrip));
    expect(strip.days, hasLength(7));

    final today = DateTime.now();
    expect(strip.days.first.date.day, today.day, reason: '첫 칸이 오늘이어야 한다');
    // 오늘 칸만 요일 대신 `오늘` 이라고 쓴다.
    expect(find.text('오늘'), findsOneWidget);

    // ⚠️ 첫 칸은 지수 카드와 같은 등급이어야 한다. 어긋나면 같은 화면에서
    //    `아주 좋음` 카드 아래 빨간 막대가 뜬다.
    //    대표 포인트는 **첫 지역의 첫 곳**이다 (`featuredSpotProvider`) — 목록의
    //    맨 앞 포인트가 아니다.
    final featured = MockData.spots.firstWhere(
      (s) => s.regionGroupId == MockData.regions.first.id,
    );
    expect(strip.days.first.rating, featured.rating);
  });

  testWidgets('★ 주간 예보가 없는 포인트면 카드를 감춘다', (tester) async {
    // KHOA 해역이 안 붙은 포인트(영종도)는 주간이 빈 목록으로 온다.
    // 빈 막대 일곱 칸은 "나쁜 한 주"로 읽히므로 섹션째 사라져야 한다.
    await pumpApp(tester, repository: _NoWeeklyRepository());

    expect(find.text('이번 주 지수'), findsNothing);
    expect(find.byType(WeeklyIndexStrip), findsNothing);
    // 나머지 홈은 그대로다.
    expect(find.text('오늘의 낚시지수'), findsOneWidget);
  });

  testWidgets('★ 수치가 없으면 0.0 이 아니라 — 로 그린다', (tester) async {
    // 서버가 `SpotResponse.toDouble(null)` 로 0 을 채워 보내던 자리다. 0.0℃ 는
    // 틀렸으면서 정밀해 보이고, 물이 얼었다는 뜻이 된다.
    await pumpApp(tester, repository: _NoMetricsRepository());

    // ⚠️ MetricColumn 은 값과 단위를 한 Text.rich 로 붙여 그린다 — `findRichText` 를
    //    빼거나 값만 찾으면 **아무것도 못 찾고 헛통과한다.**
    await tester.tap(find.text('지수'));
    await tester.pumpAndSettle();
    expect(find.text('0.0 ℃', findRichText: true), findsNothing);
    expect(find.text('— ℃', findRichText: true), findsWidgets);
    expect(find.text('— m', findRichText: true), findsWidgets);

    await tester.tap(find.byType(SpotCard).first);
    await tester.pumpAndSettle();
    expect(find.text('0.0 ℃', findRichText: true), findsNothing);
    expect(find.text('— ㎧', findRichText: true), findsWidgets);
  });

  testWidgets('★ 시간대별 예보가 없으면 그래프 카드를 감춘다', (tester) async {
    // 예전엔 서버가 없는 값을 [0,0,0,0,0,0] 으로 채워 보내서, 예보가 없는 포인트가
    // **막대 없는 그래프 위에 "06시 최적"** 이라고 단언하고 있었다.
    await pumpApp(tester, repository: _NoHourlyRepository());

    await tester.tap(find.text('지수'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SpotCard).first);
    await tester.pumpAndSettle();

    expect(find.text('시간대별 조황 예상'), findsNothing);
    expect(find.textContaining('최적'), findsNothing);
    // 나머지 상세는 그대로다.
    expect(find.text('추천 어종'), findsOneWidget);
  });

  testWidgets('★ 추천 어종이 없으면 섹션째 감춘다', (tester) async {
    // 먼바다 해역은 어종을 '-' 로만 준다. 제목만 남으면 로딩에 실패한 것처럼 보인다.
    await pumpApp(tester, repository: _NoFishRepository());

    await tester.tap(find.text('지수'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SpotCard).first);
    await tester.pumpAndSettle();

    expect(find.text('추천 어종'), findsNothing);
    // 나머지 상세는 그대로다.
    expect(find.text('시간대별 조황 예상'), findsOneWidget);
  });

  testWidgets('★ 글쓰기에서 지역을 골라 올리면 카드에 그 지역이 붙는다', (tester) async {
    // 서버는 처음부터 regionGroupId 를 받았는데 화면에 고르는 칸이 없어서,
    // 앱으로 쓴 글은 전부 지역이 비어 있었다.
    await pumpApp(tester, auth: FakeAuthRepository(loggedIn: true));

    await tester.tap(find.text('게시판'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HeaderButton, '글쓰기'));
    await tester.pumpAndSettle();

    final region = MockData.regions.first;
    expect(find.text('지역'), findsOneWidget);
    await tester.tap(find.widgetWithText(SquareChip, region.name));
    await tester.pump();

    await tester.enterText(
        find.widgetWithText(TextField, '무슨 이야기인가요?'), '지역 붙은 글');
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '본문');
    await tester.pump();
    await tester.tap(find.widgetWithText(HeaderButton, '등록'));
    await tester.pumpAndSettle();

    // 목록 카드의 지역 라벨이 고른 권역이어야 한다.
    expect(find.textContaining('${region.name} · '), findsWidgets);
  });

  testWidgets('★ 지역을 안 고른 글에는 라벨을 안 붙인다 — "전체" 는 지명이 아니다', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository(loggedIn: true));

    await tester.tap(find.text('게시판'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HeaderButton, '글쓰기'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, '무슨 이야기인가요?'), '지역 없는 글');
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '본문');
    await tester.pump();
    await tester.tap(find.widgetWithText(HeaderButton, '등록'));
    await tester.pumpAndSettle();

    expect(find.text('지역 없는 글'), findsOneWidget);
    expect(find.textContaining('전체 ·'), findsNothing);
  });

  testWidgets('★ 글을 고치면 새 글이 생기지 않는다', (tester) async {
    // 예전엔 고치기도 createPost 로 가서 `저장` 을 누르면 같은 글이 하나 더 생겼다.
    await pumpApp(tester, auth: FakeAuthRepository(loggedIn: true));

    await tester.tap(find.text('게시판'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HeaderButton, '글쓰기'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, '무슨 이야기인가요?'), '고치기 전');
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '본문');
    await tester.pump();
    await tester.tap(find.widgetWithText(HeaderButton, '등록'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('고치기 전'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, '무슨 이야기인가요?'), '고친 뒤');
    await tester.pump();
    await tester.tap(find.widgetWithText(HeaderButton, '저장'));
    await tester.pumpAndSettle();

    // 저장하면 게시판으로 돌아온다. 화면 제목과 탭 라벨이 둘 다 '게시판' 이라
    // 탭 쪽(마지막)을 집는다.
    await tester.tap(find.text('게시판').last);
    await tester.pumpAndSettle();

    expect(find.text('고친 뒤'), findsOneWidget);
    expect(find.text('고치기 전'), findsNothing, reason: '고쳤으면 옛 제목은 없어야 한다');
  });

  testWidgets('★ 비로그인이어도 설정·고객센터에는 들어갈 수 있다', (tester) async {
    // 둘 다 계정과 상관없는 기능이다. 특히 문의는 **로그인이 안 되는 사람**이
    // 가장 하고 싶은 일인데, 마이 탭이 로그인 화면으로 덮여 통로가 막혀 있었다.
    await pumpApp(tester);

    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();
    expect(find.text('로그인'), findsWidgets, reason: '비로그인 화면이 맞다');

    await tester.tap(find.text('고객센터'));
    await tester.pumpAndSettle();
    expect(find.text('자주 묻는 질문'), findsOneWidget);

    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    expect(find.text('화면 테마'), findsOneWidget);
  });

  testWidgets('★ 조과를 저장한 뒤 게시판 글쓰기로 바로 갈 수 있다', (tester) async {
    // 예전엔 "글쓰기는 로그인 연동 후 지원됩니다" 스낵바를 띄우는 죽은 버튼이었다.
    // 여기까지 온 사람은 방금 조과를 저장했으니 이미 로그인 상태다.
    await pumpApp(
      tester,
      photoPicker: FakePhotoPicker(),
      auth: FakeAuthRepository(loggedIn: true),
    );

    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HeaderButton, '등록'));
    await tester.pumpAndSettle();
    // 새 기록은 사진이 있어야 저장된다 (`_ready`).
    await pickPhoto(tester, PhotoSource.gallery);
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('부시리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 저장'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byType(CatchSuccessScreen), findsOneWidget);

    await tester.tap(find.text('게시판에 조황 올리기'));
    await tester.pumpAndSettle();

    expect(find.text('글쓰기'), findsOneWidget);
    expect(find.textContaining('로그인 연동 후'), findsNothing);
  });

  testWidgets('★ 없는 주소는 한국어 안내로 받는다', (tester) async {
    await pumpApp(tester);

    // 라우터는 FishingApp 이 들고 있다. 화면에서 갈 수 없는 주소라 여기서 직접 민다.
    GoRouter.of(tester.element(find.text('홈').last)).go('/이런건없다');
    await tester.pumpAndSettle();

    expect(find.text('없는 화면이에요'), findsOneWidget);
    expect(find.textContaining('GoException'), findsNothing);
    expect(find.text('Page Not Found'), findsNothing);

    await tester.tap(find.widgetWithText(PrimaryButton, '홈으로'));
    await tester.pumpAndSettle();
    expect(find.textContaining('오늘 출조'), findsOneWidget);
  });

  testWidgets('★ 홈에 최근 조황 글이 뜨고 누르면 상세로 간다', (tester) async {
    await pumpApp(tester);

    expect(find.text('최근 조황'), findsOneWidget);
    // 시드의 조황 글 두 개. `자유`·`질문` 글은 여기 오면 안 된다.
    expect(find.text('오늘 학리에서 감성돔 4짜 손맛!'), findsOneWidget);
    expect(find.text('초보도 잡았네요 ㅎㅎ 볼락 조황 좋아요'), findsNothing);

    await tester.tap(find.text('오늘 학리에서 감성돔 4짜 손맛!'));
    await tester.pumpAndSettle();
    expect(find.text('게시판으로'), findsOneWidget);
  });

  testWidgets('★ 게시판 탭을 바꿔도 홈의 최근 조황은 조황 그대로다', (tester) async {
    await pumpApp(tester);

    // 게시판에서 `질문` 만 보게 해 둔다.
    await tester.tap(find.text('게시판'));
    await tester.pumpAndSettle();
    await tapChip(tester, '질문');
    expect(find.text('영종도 우럭 포인트 추천 부탁드려요'), findsOneWidget);

    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();

    // 홈이 게시판 탭 상태를 구독하면 여기에 질문 글이 뜬다.
    expect(find.text('오늘 학리에서 감성돔 4짜 손맛!'), findsOneWidget);
    expect(find.text('영종도 우럭 포인트 추천 부탁드려요'), findsNothing);
  });

  testWidgets('지수 탭 → 포인트 카드 → 상세로 이동한다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('지수'));
    await tester.pumpAndSettle();
    expect(find.text('낚시 지수'), findsOneWidget);
    // 아무것도 안 골랐으면 **첫 권역**이 눌린 것으로 보여야 한다 — 예전에는 초기값이
    // 사라진 id(1) 라 목록이 비어 있었다.
    final first = MockData.regions.first;
    expect(
      find.byType(SpotCard),
      findsNWidgets(
        MockData.spots.where((s) => s.regionGroupId == first.id).length,
      ),
    );

    await tester.tap(find.byType(SpotCard).first);
    await tester.pumpAndSettle();
    expect(find.text('시간대별 조황 예상'), findsOneWidget);
    expect(find.text('추천 어종'), findsOneWidget);
    expect(find.textContaining('참고용 정보이며'), findsWidgets);
  });

  testWidgets('★ 지역 검색은 포인트 이름으로도 걸린다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('지수'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HeaderButton, '지역'));
    await tester.pumpAndSettle();

    final field = find.widgetWithText(TextField, '지역 또는 포인트 검색');
    expect(field, findsOneWidget, reason: '안내 문구가 포인트 검색을 약속한다');

    // ⚠️ 검색어가 권역 이름과 같으면 입력창 글자까지 `find.text` 에 걸린다.
    //    그래서 결과에만 나오는 말로 친다 — `부산` 은 남해의 area 에 있다.
    await tester.enterText(field, '부산');
    await tester.pumpAndSettle();
    expect(find.text('남해'), findsOneWidget);
    expect(find.text('제주'), findsNothing);

    // ⚠️ 포인트 이름으로도 걸려야 한다. `학리` 는 `기장 학리` 포인트의 이름이고
    //    권역명(`남해`)에는 없는 글자다 — 예전에는 여기서 결과가 비었다.
    //    이제 포인트 행과 그 포인트가 속한 권역이 함께 나오므로 `남해` 는 둘이다.
    await tester.enterText(field, '학리');
    await tester.pumpAndSettle();
    expect(find.text('검색 결과가 없어요'), findsNothing);
    expect(find.text('기장 학리'), findsOneWidget);
    expect(find.text('남해'), findsWidgets);

    // 한 권역의 포인트 둘이 같이 걸려도 권역은 한 번만 나온다.
    await tester.enterText(field, '기장');
    await tester.pumpAndSettle();
    expect(find.text('남해'), findsWidgets);
  });

  /// 지수 → 지역 선택 화면.
  Future<void> openRegionSearch(WidgetTester tester) async {
    await tester.tap(find.text('지수'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HeaderButton, '지역'));
    await tester.pumpAndSettle();
  }

  testWidgets('★ 현재 위치로 찾으면 가까운 순으로 거리와 함께 뜬다', (tester) async {
    await pumpApp(tester, location: FakeLocationService.allowed());
    await openRegionSearch(tester);

    // 예전에는 `위치 기반 검색은 API 연동 후 지원됩니다` 스낵바만 떴다.
    await tester.tap(find.widgetWithText(PrimaryButton, '현재 위치로 찾기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('가까운 포인트'), findsOneWidget);
    expect(find.textContaining('준비 중'), findsNothing);
    // 거리가 포인트 행에 붙는다 — 가까운 순이라는 걸 숫자로 보여줘야 한다.
    expect(find.textContaining('km'), findsWidgets);
  });

  testWidgets('★ 위치를 거부하면 오류 화면이 아니라 안내 한 줄이다', (tester) async {
    await pumpApp(tester, location: FakeLocationService.denied());
    await openRegionSearch(tester);

    await tester.tap(find.widgetWithText(PrimaryButton, '현재 위치로 찾기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 거부는 오류가 아니라 사용자의 선택이다. 화면은 그대로 쓸 수 있어야 한다.
    expect(find.text('위치 권한이 필요해요'), findsOneWidget);
    expect(find.text('가까운 포인트'), findsNothing);
    expect(find.text('전체 지역'), findsOneWidget);
  });

  testWidgets('★ 영구 거부면 설정으로 보내는 버튼을 함께 준다', (tester) async {
    await pumpApp(tester, location: FakeLocationService.denied(forever: true));
    await openRegionSearch(tester);

    await tester.tap(find.widgetWithText(PrimaryButton, '현재 위치로 찾기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 앱 안에서는 풀 방법이 없다 — 설정으로 가는 길을 줘야 막다른 길이 아니다.
    expect(find.textContaining('설정에서 켜주세요'), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, '설정'), findsOneWidget);
  });

  testWidgets('★ 검색에 걸린 포인트를 눌러 바로 그 상세로 간다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('지수'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HeaderButton, '지역'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '지역 또는 포인트 검색'),
      '울릉',
    );
    await tester.pumpAndSettle();

    // 포인트 섹션이 지역보다 먼저 나온다 — `울릉` 을 친 사람이 원하는 건 권역이 아니다.
    expect(find.text('포인트'), findsOneWidget);
    expect(find.text('울릉도'), findsOneWidget);

    await tester.tap(find.text('울릉도'));
    await tester.pumpAndSettle();

    // 권역을 거치지 않고 그 포인트 상세로 바로 간다.
    expect(find.text('시간대별 조황 예상'), findsOneWidget);
    expect(find.text('지역 선택'), findsNothing);
  });

  testWidgets('지역 칩을 바꾸면 포인트 목록이 갱신된다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('지수'));
    await tester.pumpAndSettle();

    // 첫 권역(동해)에서 남해로 옮긴다.
    expect(find.text('구룡포 방파제'), findsOneWidget);

    await tapChip(tester, '남해');
    expect(find.text('사량도 옥동'), findsOneWidget);
    expect(find.text('구룡포 방파제'), findsNothing);
  });

  testWidgets('도감 그리드가 등록/미등록 칸을 함께 보여준다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();

    expect(find.text('어류 도감'), findsOneWidget);
    expect(find.byType(SpeciesTile), findsWidgets);
    // ★ 미등록 칸도 **이름을 보여준다** (기획서 2-3). 뭘 잡아야 할지 알아야
    //   다음 출조 동기가 생긴다. 한동안 "미기록" 으로 가려서 36칸이 다 똑같았다.
    expect(find.text('감성돔'), findsOneWidget);
    expect(find.text('미기록'), findsNothing);
    // 시드에 기록이 없는 종. 실루엣 칸이지만 이름은 읽힌다.
    expect(find.text('부시리'), findsOneWidget);
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
    expect(find.text('내 기록'), findsOneWidget);
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

  testWidgets('★ 로그인을 건너뛰면 막힌 화면이 아니라 왔던 자리로 되돌아간다', (tester) async {
    await pumpApp(tester);
    // 도감에서 `등록` 을 눌러 관문에 막힌 상황이다.
    await goToLogin(tester);

    // `나중에 하기` 는 글자에서 `<` 아이콘으로 바뀌었다. 집을 글자가 없으므로
    // 아이콘으로 찾는다.
    final back = find.byWidgetPredicate(
      (w) => w is IconTapButton && w.icon == AppIcon.chevronLeft,
    );
    expect(back, findsOneWidget);

    await tester.tap(back);
    await tester.pumpAndSettle();

    expect(find.textContaining('로그인이 필요해요'), findsNothing);
    // ⚠️ 왔던 자리(도감)로 돌아가야 한다. `기록 추가` 로 가면 로그인 관문을
    //    그냥 통과시킨 셈이 된다 — 그 화면은 로그인이 끝났다고 가정하고 짜여 있다.
    expect(find.text('기록 추가'), findsNothing);
    expect(find.text('어류 도감'), findsOneWidget);
  });

  testWidgets('★ 이메일·비밀번호로도 로그인할 수 있다 (소셜만 있는 게 아니다)', (tester) async {
    final auth = FakeAuthRepository();
    await pumpApp(tester, auth: auth);

    await goToLogin(tester);

    await tester.enterText(find.widgetWithText(TextField, '이메일'), 'hong@example.com');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호'), 'hyun1234');
    await tester.tap(find.widgetWithText(PrimaryButton, '로그인'));
    await tester.pumpAndSettle();

    expect(auth.lastEmail, 'hong@example.com');
    expect(auth.lastPassword, 'hyun1234');
    expect(find.text('기록 추가'), findsOneWidget, reason: '로그인 후 원래 목적지로 가야 한다');
  });

  testWidgets('★ 회원가입으로 계정을 만들면 그대로 로그인 상태가 된다', (tester) async {
    final auth = FakeAuthRepository();
    await pumpApp(tester, auth: auth);

    await goToLogin(tester);
    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();

    expect(find.text('이메일로 시작하기'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'name@example.com'),
      'hong@example.com',
    );
    await tester.enterText(find.widgetWithText(TextField, '8자 이상'), 'hyun1234');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호 확인'), 'hyun1234');
    await tester.enterText(
      find.widgetWithText(TextField, '도감과 게시판에 표시돼요'),
      '테스트조사',
    );
    await tester.tap(find.widgetWithText(PrimaryButton, '가입하고 시작하기'));
    await tester.pumpAndSettle();

    expect(auth.lastEmail, 'hong@example.com');
    expect(auth.lastNickname, '테스트조사');
    // 가입 응답에 토큰이 함께 오므로 다시 로그인시키지 않는다.
    expect(find.text('기록 추가'), findsOneWidget);
  });

  testWidgets('★ 비밀번호 확인이 다르면 서버까지 가지 않는다', (tester) async {
    final auth = FakeAuthRepository();
    await pumpApp(tester, auth: auth);

    await goToLogin(tester);
    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'name@example.com'),
      'hong@example.com',
    );
    await tester.enterText(find.widgetWithText(TextField, '8자 이상'), 'hyun1234');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호 확인'), 'hyun9999');
    await tester.enterText(
      find.widgetWithText(TextField, '도감과 게시판에 표시돼요'),
      '테스트조사',
    );
    await tester.tap(find.widgetWithText(PrimaryButton, '가입하고 시작하기'));
    await tester.pumpAndSettle();

    expect(auth.lastEmail, isNull, reason: '왕복하지 않고 그 자리에서 막아야 한다');
    expect(find.text('비밀번호가 서로 다릅니다'), findsOneWidget);
  });

  testWidgets('★ 로그인이 실패하면 이유가 화면에 남는다', (tester) async {
    await pumpApp(tester, auth: FailingAuthRepository());

    await goToLogin(tester);
    await tester.enterText(find.widgetWithText(TextField, '이메일'), 'a@b.com');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, '비밀번호'), 'hyun1234');
    await tester.pump();
    await tester.tap(find.widgetWithText(PrimaryButton, '로그인'));
    await tester.pumpAndSettle();

    // ⚠️ pumpAndSettle 이 지난 뒤에도 남아 있어야 한다. 스낵바였을 때는 4초 뒤
    //    스스로 사라져서, 눈을 잠깐 뗀 사용자는 이유를 영영 못 봤다.
    expect(find.text('이메일 또는 비밀번호가 올바르지 않습니다'), findsOneWidget);
    expect(find.text('기록 추가'), findsNothing, reason: '실패했으니 통과시키면 안 된다');

    // 고치기 시작하면 사라진다 — 방금 바꾼 값에 대한 판정이 아직 없다.
    await tester.enterText(find.widgetWithText(TextField, '이메일'), 'a@b.co');
    await tester.pumpAndSettle();
    expect(find.text('이메일 또는 비밀번호가 올바르지 않습니다'), findsNothing);
  });

  testWidgets('★ 가입한 계정으로 카카오를 누르면 새 계정이 아니라 연동이 뜬다', (tester) async {
    final auth = FakeAuthRepository(linkRequired: true);
    await pumpApp(tester, auth: auth);

    await goToLogin(tester);
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    // 로그인이 끝난 것이 아니라 비밀번호를 한 번 더 묻는다.
    expect(find.text('계정을 연결할까요?'), findsOneWidget);
    expect(find.textContaining('hong@example.com'), findsOneWidget);
    expect(find.text('기록 추가'), findsNothing);

    // 뒤에 깔린 로그인 화면에도 '비밀번호' 칸이 있다. 대화상자 안으로 좁힌다.
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'hyun1234',
    );
    await tester.tap(find.text('연결하기'));
    await tester.pumpAndSettle();

    expect(auth.linkedSocial, isTrue);
    expect(auth.lastPassword, 'hyun1234');
    expect(find.text('기록 추가'), findsOneWidget, reason: '연동 후 원래 목적지로 가야 한다');
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
    expect(find.text('사진 · 0 / 5'), findsOneWidget);
    await pickPhoto(tester, PhotoSource.gallery);
    expect(picker.lastSource, PhotoSource.gallery);
    expect(find.text('사진 · 1 / 5'), findsOneWidget);
    // 추가 칸은 남아 있되 문구가 바뀐다 — 더 넣을 수 있다는 뜻이다.
    expect(find.text('사진 추가'), findsNothing);
    expect(find.text('더 넣기'), findsOneWidget);
    // 첫 장이 도감 칸의 표지가 된다는 배지
    expect(find.text('대표'), findsOneWidget);

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

  testWidgets('★ 사진을 여러 장 넣고 빼면 순서와 개수가 따라간다 (V11)', (tester) async {
    await pumpApp(
      tester,
      photoPicker: FakePhotoPicker(),
      auth: FakeAuthRepository(loggedIn: true),
    );

    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HeaderButton, '등록'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await pickPhoto(tester, PhotoSource.gallery);
    }
    expect(find.text('사진 · 3 / 5'), findsOneWidget);
    // 표지는 언제나 하나다 — 첫 장에만 붙는다.
    expect(find.text('대표'), findsOneWidget);

    // 한 장 빼면 개수가 줄고 남은 첫 장이 표지를 이어받는다.
    // x 아이콘뿐이라 집을 글자가 없다 — 스크린 리더에 준 이름으로 찾는다.
    // (`bySemanticsLabel` 은 합쳐진 노드 전체를 집어 탭이 빗나간다.)
    final remove = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == '사진 빼기',
    );
    expect(remove, findsNWidgets(3));
    await tester.tap(remove.first);
    await tester.pumpAndSettle();
    expect(find.text('사진 · 2 / 5'), findsOneWidget);
    expect(find.text('대표'), findsOneWidget);
  });

  testWidgets('★ 길이를 비워도 저장된다 — 길이는 선택이다 (V11)', (tester) async {
    await pumpApp(
      tester,
      photoPicker: FakePhotoPicker(),
      auth: FakeAuthRepository(loggedIn: true),
    );

    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HeaderButton, '등록'));
    await tester.pumpAndSettle();

    // 시안의 라벨 그대로. 놓아준 물고기나 사진만 남기고 싶은 기록이 있다.
    expect(find.text('길이 (선택)'), findsOneWidget);

    await pickPhoto(tester, PhotoSource.gallery);
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('부시리'));
    await tester.pumpAndSettle();

    // ★ 길이를 한 글자도 안 적은 채로 저장한다.
    await tester.tap(find.text('기록 저장'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(CatchSuccessScreen), findsOneWidget);
    // 큰 숫자 자리는 0.0 이 아니라 비워 둔다 — 0cm 를 잰 것처럼 읽히면 안 된다.
    expect(find.text('0.0'), findsNothing);
    expect(find.text('—'), findsWidgets);
  });

  // ── 기록 수정 (계약서 3-7-3) ──────────────────────────────────

  /// 도감 → 감성돔 상세 → 첫 기록의 수정 버튼.
  Future<void> openCatchEdit(WidgetTester tester) async {
    await tester.tap(find.text('도감'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('감성돔'));
    await tester.pumpAndSettle();

    final pencil = find.byWidgetPredicate(
      (w) => w is IconTapButton && w.icon == AppIcon.pencil,
    );
    await tester.ensureVisible(pencil.first);
    await tester.pumpAndSettle();
    await tester.tap(pencil.first);
    await tester.pumpAndSettle();
  }

  testWidgets('★ 기록 수정 화면은 기존 값으로 채워져 있다', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository(loggedIn: true));
    await openCatchEdit(tester);

    expect(find.text('기록 수정'), findsOneWidget);
    // 시드 첫 기록 — 42.5cm · 기장 학리 · 감성돔.
    expect(find.text('42.5'), findsWidgets);
    expect(find.text('기장 학리'), findsWidgets);
    expect(find.text('감성돔'), findsWidgets);
    // 어종이 채워졌으니 `선택` 자리 표시는 없어야 한다.
    expect(find.text('선택'), findsNothing);
  });

  testWidgets('★ 길이를 고치면 목록에 반영된다', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository(loggedIn: true));
    await openCatchEdit(tester);

    final lengthField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == '0.0',
    );
    await tester.enterText(lengthField, '44.1');
    await tester.pumpAndSettle();

    await tester.tap(find.text('수정 저장'));
    await tester.pump();
    // 목 리포지토리의 지연을 넘긴다 (등록 테스트와 같은 이유).
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('기록을 수정했습니다'), findsOneWidget);
    // 고친 값이 어종 상세로 돌아와 보인다. 42.5 는 더 이상 최고 기록이 아니다.
    expect(find.textContaining('44.1'), findsWidgets);
  });

  testWidgets('★ 사진 없는 기록도 고칠 수 있다 — 등록과 달리 사진을 요구하지 않는다', (tester) async {
    // 시드 기록에는 인증샷이 없다. 여기서까지 사진을 요구하면 그 기록의 오타를
    // 영영 못 고친다.
    await pumpApp(tester, auth: FakeAuthRepository(loggedIn: true));
    await openCatchEdit(tester);

    expect(find.text('사진 · 0 / 5'), findsOneWidget);
    expect(
      tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, '수정 저장'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('★ 비로그인으로 글쓰기를 누르면 로그인 화면으로 보낸다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('게시판'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HeaderButton, '글쓰기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('로그인이 필요해요'), findsOneWidget);
    // 예전에는 "로그인 연동 후 지원됩니다" 스낵바만 뜨고 끝이었다.
    expect(find.textContaining('연동 후'), findsNothing);
  });

  testWidgets('★ 로그인 상태에서 글을 쓰면 목록 맨 앞에 뜬다', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository(loggedIn: true));

    await tester.tap(find.text('게시판'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HeaderButton, '글쓰기'));
    await tester.pumpAndSettle();

    expect(find.text('글쓰기'), findsWidgets, reason: '관문을 그냥 통과해야 한다');

    await tester.enterText(
      find.widgetWithText(TextField, '무슨 이야기인가요?'),
      '학리에서 감성돔 4짜',
    );
    // 본문 칸은 힌트가 두 줄이라 문구로 찾지 않는다 — 화면의 두 번째(마지막) 입력이다.
    await tester.enterText(
      find.byType(TextField).last,
      '새벽 물때에 입질이 좋았습니다.',
    );
    // 리빌드를 기다린다. 안 기다리면 등록 버튼이 아직 비활성 콜백을 물고 있어
    // 탭이 아무 일도 하지 않는다.
    await tester.pump();
    await tester.tap(find.widgetWithText(HeaderButton, '등록'));
    await tester.pumpAndSettle();

    // 글쓰기 화면을 떠나 게시판으로 돌아와야 한다.
    // ⚠️ 이 단언이 **먼저**다. find.text 는 EditableText 도 잡기 때문에, 화면을 못 떠났으면
    //    입력칸에 남은 제목이 "목록에 보인다"로 잘못 통과한다 — 실제로 그렇게 통과했었다.
    expect(find.byType(TextField), findsNothing, reason: '글쓰기 화면을 떠나야 한다');
    expect(find.text('학리에서 감성돔 4짜'), findsOneWidget, reason: '쓴 글이 목록에 보여야 한다');

    // ★ 저장이 됐는데 실패로 안내하면 안 된다.
    //
    //    처음 만들 때 화면 전환(context.pop)이 try 안에 있었다. 이 화면은 requireLogin 이
    //    go 로 열어서 스택에 쌓인 것이 없어 pop 이 던졌고, 그 예외가 저장 실패로 둔갑해
    //    "글을 올리지 못했어요"가 떴다 — 글은 이미 저장된 뒤였다.
    //    사용자는 실패한 줄 알고 다시 눌러 같은 글을 두 번 올렸다.
    expect(find.textContaining('올리지 못했어요'), findsNothing);
    expect(find.text('글을 올렸어요'), findsOneWidget);
  });

  testWidgets('★ 글 카드를 누르면 상세로 가고 본문이 보인다 (비로그인도)', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('게시판'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('오늘 학리에서 감성돔 4짜 손맛!'));
    await tester.pumpAndSettle();

    // 카드에는 요약만 있었다. 상세는 본문과 댓글 자리를 함께 보여준다.
    expect(find.text('게시판으로'), findsOneWidget);
    expect(find.textContaining('댓글'), findsWidgets);
    expect(find.textContaining('아직 댓글이 없어요'), findsOneWidget);
  });

  testWidgets('★ 로그인 상태에서 댓글을 남기면 목록에 붙는다', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository(loggedIn: true));

    await tester.tap(find.text('게시판'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('오늘 학리에서 감성돔 4짜 손맛!'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '댓글을 남겨보세요'),
      '저도 어제 다녀왔어요',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(PressScale, '등록'));
    await tester.pumpAndSettle();

    expect(find.text('저도 어제 다녀왔어요'), findsOneWidget);
    expect(find.textContaining('아직 댓글이 없어요'), findsNothing);
  });

  testWidgets('★ 비로그인으로 좋아요를 누르면 로그인 화면으로 보낸다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('게시판'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('오늘 학리에서 감성돔 4짜 손맛!'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('좋아요'));
    await tester.pumpAndSettle();

    expect(find.textContaining('로그인이 필요해요'), findsOneWidget);
  });

  // ── 신고 (계약서 3-8) ─────────────────────────────────────────

  /// 게시판 → 첫 글 상세.
  Future<void> openPost(WidgetTester tester) async {
    await tester.tap(find.text('게시판'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('오늘 학리에서 감성돔 4짜 손맛!'));
    await tester.pumpAndSettle();
  }

  testWidgets('★ 남의 글은 신고할 수 있고, 사유를 골라야 보낼 수 있다', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository(loggedIn: true));
    await openPost(tester);

    await tester.tap(find.text('신고'));
    await tester.pumpAndSettle();
    expect(find.text('이 글을 신고할까요?'), findsOneWidget);
    // 신고해도 글이 남는다는 것을 시트에서 미리 말해 준다.
    expect(find.textContaining('바로 내려가지는 않아요'), findsOneWidget);

    // 사유를 고르기 전에는 보낼 수 없다.
    expect(
      tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, '신고하기'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('스팸 · 광고'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, '신고하기'));
    await tester.pumpAndSettle();

    expect(find.text('신고를 접수했어요'), findsOneWidget);
  });

  testWidgets('★ 같은 글을 두 번 신고하면 실패가 아니라 "이미 신고" 다', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository(loggedIn: true));
    await openPost(tester);

    for (final expected in ['신고를 접수했어요', '이미 신고한 글이에요']) {
      // 앞선 스낵바가 시트 버튼을 덮는다. 사라질 때까지 기다린다 (기본 4초).
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tester.tap(find.text('신고'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('욕설 · 비방'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrimaryButton, '신고하기'));
      await tester.pumpAndSettle();

      expect(find.text(expected), findsOneWidget);
    }
  });

  testWidgets('★ `기타` 는 설명을 적어야 보낼 수 있다', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository(loggedIn: true));
    await openPost(tester);

    await tester.tap(find.text('신고'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기타'));
    await tester.pumpAndSettle();

    // 사유는 골랐지만 설명이 비어 있다 — 사유 이름만으로는 처리할 수 없는 신고다.
    expect(
      tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, '신고하기'))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField).last, '같은 사진을 계속 올려요');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, '신고하기'));
    await tester.pumpAndSettle();

    expect(find.text('신고를 접수했어요'), findsOneWidget);
  });

  testWidgets('★ 비로그인으로 신고하면 사유를 고른 뒤 로그인 화면으로 보낸다', (tester) async {
    await pumpApp(tester);
    await openPost(tester);

    // 순서가 중요하다 — 사유도 못 본 채 튕기면 무엇을 하려던 건지 알 수 없다.
    await tester.tap(find.text('신고'));
    await tester.pumpAndSettle();
    expect(find.text('이 글을 신고할까요?'), findsOneWidget);

    await tester.tap(find.text('스팸 · 광고'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, '신고하기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('로그인이 필요해요'), findsOneWidget);
  });

  testWidgets('★ 사진을 붙여 글을 쓸 수 있다 (사진은 선택)', (tester) async {
    final picker = FakePhotoPicker();
    await pumpApp(
      tester,
      photoPicker: picker,
      auth: FakeAuthRepository(loggedIn: true),
    );

    await tester.tap(find.text('게시판'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HeaderButton, '글쓰기'));
    await tester.pumpAndSettle();

    // 사진 없이도 올릴 수 있어야 한다 — 질문 글에 사진을 강요하지 않는다.
    expect(find.text('사진 추가 (선택)'), findsOneWidget);

    await tester.tap(find.text('사진 추가 (선택)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(PhotoSource.gallery.label));
    await tester.pumpAndSettle();

    expect(picker.lastSource, PhotoSource.gallery);
    // 고른 사진이 그 자리에 미리보기로 뜨고, 안내 문구는 물러난다.
    expect(find.text('사진 추가 (선택)'), findsNothing);
    expect(find.text('사진 바꾸기'), findsOneWidget);
  });

  testWidgets('★ 내 글만 수정·삭제가 보인다', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository(loggedIn: true));

    await tester.tap(find.text('게시판'));
    await tester.pumpAndSettle();
    // 시드 글은 user_id 가 없어 누구의 것도 아니다 (mine=false).
    await tester.tap(find.text('오늘 학리에서 감성돔 4짜 손맛!'));
    await tester.pumpAndSettle();
    expect(find.text('삭제'), findsNothing, reason: '남의 글에는 없어야 한다');
    // 그 자리에 신고가 대신 붙는다 (계약서 3-8).
    expect(find.text('신고'), findsOneWidget);

    // 내가 쓴 글에는 붙는다.
    // ⚠️ BackRow 의 '게시판으로' 는 라벨이라 눌리지 않는다 (아이콘 버튼만 탭 대상).
    //    같은 탭을 다시 누르면 그 브랜치의 첫 화면으로 되돌아간다.
    await tester.tap(find.text('게시판'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HeaderButton, '글쓰기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '무슨 이야기인가요?'), '내가 쓴 글');
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '본문');
    await tester.pump();
    await tester.tap(find.widgetWithText(HeaderButton, '등록'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('내가 쓴 글'));
    await tester.pumpAndSettle();
    expect(find.text('수정'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
    // 내 글은 신고할 수 없다 — 서버도 400 이다.
    expect(find.text('신고'), findsNothing);
  });

  testWidgets('★ 글을 지우면 목록에서 사라진다 (되묻고 나서)', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository(loggedIn: true));

    await tester.tap(find.text('게시판'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HeaderButton, '글쓰기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '무슨 이야기인가요?'), '지울 글');
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '본문');
    await tester.pump();
    await tester.tap(find.widgetWithText(HeaderButton, '등록'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('지울 글'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    // 되돌릴 수 없는 동작이라 한 번 되묻는다.
    expect(find.text('글을 지울까요?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    expect(find.text('지울 글'), findsNothing, reason: '목록에서 사라져야 한다');
    expect(find.text('글을 지웠어요'), findsOneWidget);
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
    // 알림 설정도 뺐다 — 켜고 끌 알림이 하나도 없다 (FCM 미도입).
    expect(find.text('알림 설정'), findsNothing);
  });

  // ── 고객센터 ──────────────────────────────────────────────────

  testWidgets('★ 마이 > 고객센터에서 FAQ 를 펼쳐 읽는다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('고객센터'));
    await tester.pumpAndSettle();

    expect(find.text('자주 묻는 질문'), findsOneWidget);
    expect(find.text('앱 정보'), findsOneWidget);

    // 답은 접혀 있다 — 아홉 개를 다 펼쳐 두면 질문을 훑을 수가 없다.
    const question = '도감은 어떻게 채워지나요?';
    expect(find.text(question), findsOneWidget);
    expect(find.textContaining('그 어종 칸이 열립니다'), findsNothing);

    await tester.tap(find.text(question));
    await tester.pumpAndSettle();
    expect(find.textContaining('그 어종 칸이 열립니다'), findsOneWidget);

    // 다시 누르면 접힌다.
    await tester.tap(find.text(question));
    await tester.pumpAndSettle();
    expect(find.textContaining('그 어종 칸이 열립니다'), findsNothing);
  });

  testWidgets('★ 고객센터는 준비 중 스낵바가 아니라 진짜 화면이다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('고객센터'));
    await tester.pumpAndSettle();

    expect(find.textContaining('준비 중'), findsNothing);
    // 마이페이지를 떠났다.
    expect(find.text('도감 진행률'), findsNothing);
  });

  // ── 다크 모드 ─────────────────────────────────────────────────

  /// 하단 탭 바의 면 색. 설정 화면 **밖**이라, 여기까지 색이 바뀌어야
  /// "고른 테마가 앱 전체에 적용됐다"고 할 수 있다.
  Color navBarSurface(WidgetTester tester) {
    final box = tester.widget<Container>(
      find
          .descendant(of: find.byType(BottomNavBar), matching: find.byType(Container))
          .first,
    );
    return (box.decoration! as BoxDecoration).color!;
  }

  Future<void> goToSettings(WidgetTester tester) async {
    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
  }

  testWidgets('★ 마이 > 설정에서 다크를 고르면 다른 화면까지 어두워진다', (tester) async {
    addTearDown(() => AppColors.use(AppPalette.light));
    await pumpApp(tester);

    expect(AppColors.isDark, isFalse);
    expect(navBarSurface(tester), AppPalette.light.surface);

    await goToSettings(tester);
    await tester.tap(find.text('다크'));
    await tester.pumpAndSettle();

    expect(AppColors.isDark, isTrue);
    // 설정 화면이 아니라 하단 탭 바다 — 트리 전체가 다시 그려졌다는 뜻.
    expect(navBarSurface(tester), AppPalette.dark.surface);

    // 되돌리기도 같은 자리에서 된다.
    await tester.tap(find.text('라이트'));
    await tester.pumpAndSettle();
    expect(AppColors.isDark, isFalse);
    expect(navBarSurface(tester), AppPalette.light.surface);
  });

  testWidgets('★ 시스템 설정을 따르면 기기가 밤 모드로 바뀔 때 같이 어두워진다', (tester) async {
    addTearDown(() => AppColors.use(AppPalette.light));
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpApp(tester);
    // 기본값이 '시스템 설정 따름' 이라 따로 고르지 않는다.
    expect(AppColors.isDark, isFalse);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();

    expect(AppColors.isDark, isTrue);
    expect(navBarSurface(tester), AppPalette.dark.surface);
  });

  testWidgets('★ 다크로 바꿔도 보고 있던 화면에 그대로 남는다', (tester) async {
    addTearDown(() => AppColors.use(AppPalette.light));
    await pumpApp(tester);

    await goToSettings(tester);
    await tester.tap(find.text('다크'));
    await tester.pumpAndSettle();

    // 트리를 통째로 다시 만들면 여기서 홈으로 튕긴다.
    expect(find.text('화면 테마'), findsOneWidget);
  });
}
