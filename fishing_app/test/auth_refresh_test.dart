import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/data/mock_data.dart';
import 'package:fishing_app/models/models.dart';
import 'package:fishing_app/services/auth_controller.dart';
import 'package:fishing_app/services/auth_repository.dart';
import 'package:fishing_app/services/mock_fishing_repository.dart';
import 'package:fishing_app/services/providers.dart';
import 'package:fishing_app/services/social_sign_in.dart';

/// 로그인 여부에 따라 다르게 답하는 저장소.
///
/// 기본 [MockFishingRepository] 는 로그인을 보지 않고 언제나 프로필을 내주기 때문에
/// 이 회귀를 재현할 수 없다. 진짜 [RemoteFishingRepository] 는 비로그인일 때
/// 프로필을 null, 도감을 전 칸 잠금으로 돌려주므로 그 동작을 흉내낸다.
class _LoginAwareRepository extends MockFishingRepository {
  _LoginAwareRepository(this._auth);

  final _FakeAuth _auth;

  int profileFetches = 0;
  int collectionFetches = 0;

  @override
  Future<Profile?> fetchProfile() async {
    profileFetches++;
    return _auth.loggedIn ? MockData.profile : null;
  }

  @override
  Future<List<CollectionEntry>> fetchCollection() async {
    collectionFetches++;
    if (_auth.loggedIn) return super.fetchCollection();
    // 비로그인 — 마스터 도감을 전 칸 잠금으로 그린다.
    final all = await super.fetchCollection();
    return all.map((e) => CollectionEntry(species: e.species)).toList();
  }
}

class _FakeAuth implements AuthRepository {
  bool loggedIn = false;

  @override
  Future<AuthUser> signIn(SocialProvider provider) async {
    loggedIn = true;
    return const AuthUser(id: 7, nickname: '테스트조사');
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String nickname,
    required List<ConsentAnswer> consents,
  }) async {
    loggedIn = true;
    return AuthUser(id: 8, nickname: nickname);
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    loggedIn = true;
    return const AuthUser(id: 7, nickname: '테스트조사');
  }

  @override
  Future<AuthUser> linkSocial(SocialLinkRequired link, String password) async {
    loggedIn = true;
    return const AuthUser(id: 7, nickname: '테스트조사');
  }

  @override
  Future<void> signOut() async => loggedIn = false;

  @override
  Future<void> withdraw() async => loggedIn = false;

  @override
  Future<bool> get isLoggedIn async => loggedIn;
}

void main() {
  late _FakeAuth auth;
  late _LoginAwareRepository repository;
  late ProviderContainer container;

  setUp(() {
    auth = _FakeAuth();
    repository = _LoginAwareRepository(auth);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        fishingRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  test('★ 비로그인으로 마이페이지를 본 뒤 로그인하면 프로필을 다시 불러온다', () async {
    // ① 비로그인 상태에서 마이페이지를 연다 — 여기서 null 이 캐시된다.
    expect(await container.read(profileProvider.future), isNull);
    expect(repository.profileFetches, 1);

    // ② 로그인한다.
    final ok = await container
        .read(authControllerProvider.notifier)
        .signInWithEmail(email: 'hong@example.com', password: 'hyun1234');
    expect(ok, isTrue);

    // ③ 다시 마이페이지로 돌아온다.
    //    로그인 상태를 구독하지 않으면 ①의 null 이 그대로 나와서
    //    **로그인했는데도 "로그인이 필요해요" 화면이 뜬다.**
    final profile = await container.read(profileProvider.future);
    expect(profile, isNotNull, reason: '로그인 후에는 프로필이 보여야 한다');
    expect(repository.profileFetches, 2, reason: '다시 불러왔어야 한다');
  });

  test('★ 도감도 로그인 후 다시 불러온다 (전 칸 잠금이 굳으면 안 된다)', () async {
    final lockedOut = await container.read(collectionProvider.future);
    expect(lockedOut.every((e) => !e.owned), isTrue, reason: '비로그인은 전 칸 잠금');

    await container
        .read(authControllerProvider.notifier)
        .signInWithEmail(email: 'hong@example.com', password: 'hyun1234');

    final afterLogin = await container.read(collectionProvider.future);
    expect(
      afterLogin.any((e) => e.owned),
      isTrue,
      reason: '로그인하면 내 기록이 반영된 도감이어야 한다',
    );
  });

  test('★ 로그아웃하면 남의 화면이 남지 않는다', () async {
    await container
        .read(authControllerProvider.notifier)
        .signInWithEmail(email: 'hong@example.com', password: 'hyun1234');
    expect(await container.read(profileProvider.future), isNotNull);

    await container.read(authControllerProvider.notifier).signOut();

    expect(
      await container.read(profileProvider.future),
      isNull,
      reason: '로그아웃했는데 이전 사용자의 프로필이 남아 있으면 안 된다',
    );
  });
}
