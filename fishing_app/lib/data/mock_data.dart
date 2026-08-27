import '../models/models.dart';

/// 시안의 SPOTS/GROUPS/POSTS/PROFILE 배열을 옮긴 시드 데이터.
///
/// 어종 마스터는 [SpeciesSeed], 내 조과 기록은 [CatchSeed]에 따로 둔다.
/// 운세 시드는 Rev 2에서 화면이 사라져 함께 제거했다.
///
/// app-fishing API가 붙으면 [RemoteFishingRepository]로 교체된다.
abstract final class MockData {
  /// 권역 넷. 서버 `V14` 와 **이름도 id 도 같아야 한다** — 다르면 USE_MOCK 을 끄는 순간
  /// 지역 칩이 통째로 바뀐다.
  ///
  /// 해역명이 `부산동부`·`인천항 서측(24km)` 처럼 예보 구역 이름이라 시도로 묶으면 이름과
  /// 그룹이 따로 논다. 권역은 좌표로 갈리므로 배정하다 틀릴 일도 없다.
  static const regions = <RegionGroup>[
    RegionGroup(
      id: 101,
      name: '동해',
      area: '강원 · 경북 · 울산',
      previewRating: Rating.bad,
      previewWaterTemp: 16.8,
      spotCount: 2,
    ),
    RegionGroup(
      id: 102,
      name: '서해',
      area: '인천 · 충남 · 전북 · 전남 서부',
      previewRating: Rating.normal,
      previewWaterTemp: 16.2,
      spotCount: 1,
    ),
    RegionGroup(
      id: 103,
      name: '남해',
      area: '부산 · 경남 · 전남 동부',
      previewRating: Rating.veryGood,
      previewWaterTemp: 18.4,
      spotCount: 4,
    ),
    RegionGroup(
      id: 104,
      name: '제주',
      area: '제주특별자치도',
      previewRating: Rating.good,
      previewWaterTemp: 21.3,
      spotCount: 1,
    ),
  ];

  static final spots = <Spot>[
    Spot(
      id: 1,
      name: '기장 학리',
      regionGroupId: 103,
      regionName: '남해',
      rating: Rating.veryGood,
      waterTemp: 18.4,
      waveHeight: 0.4,
      windSpeed: 2.1,
      weather: '맑음',
      tideInfo: '5물 · 만조 13:20',
      sunriseSunset: '05:11 / 19:42',
      comment: '바람 약하고 파고 낮아 출조하기 아주 좋은 날입니다.',
      hourlyForecast: const [55, 70, 82, 76, 68, 60],
      recommendedFish: const ['감성돔', '벵에돔', '농어'],
      updatedAt: _updatedAt,
      weeklyIndex: _week(1, Rating.veryGood),
    ),
    Spot(
      id: 2,
      name: '기장 대변항 방파제',
      regionGroupId: 103,
      regionName: '남해',
      rating: Rating.good,
      waterTemp: 17.9,
      waveHeight: 0.6,
      windSpeed: 3.0,
      weather: '구름조금',
      tideInfo: '5물 · 간조 19:40',
      sunriseSunset: '05:11 / 19:42',
      comment: '오후 들어 입질이 활발해질 것으로 보입니다.',
      hourlyForecast: const [40, 52, 60, 72, 80, 66],
      recommendedFish: const ['고등어', '전갱이', '학공치'],
      updatedAt: _updatedAt,
      weeklyIndex: _week(2, Rating.good),
    ),
    Spot(
      id: 3,
      name: '영종도 선착장',
      regionGroupId: 102,
      regionName: '서해',
      rating: Rating.normal,
      waterTemp: 16.2,
      waveHeight: 0.9,
      windSpeed: 5.2,
      weather: '흐림',
      tideInfo: '7물 · 만조 14:05',
      sunriseSunset: '05:14 / 19:48',
      comment: '물때는 좋으나 오후 바람에 주의가 필요합니다.',
      hourlyForecast: const [45, 55, 50, 48, 42, 38],
      recommendedFish: const ['우럭', '광어', '놀래미'],
      updatedAt: _updatedAt,
      weeklyIndex: _week(3, Rating.normal),
    ),
    Spot(
      id: 4,
      name: '돌산 갯바위',
      regionGroupId: 103,
      regionName: '남해',
      rating: Rating.good,
      waterTemp: 19.1,
      waveHeight: 0.5,
      windSpeed: 2.6,
      weather: '맑음',
      tideInfo: '4물 · 만조 12:30',
      sunriseSunset: '05:18 / 19:45',
      comment: '수온 안정적이고 잔잔해 가족 출조에 좋습니다.',
      hourlyForecast: const [50, 62, 70, 68, 64, 58],
      recommendedFish: const ['감성돔', '볼락', '농어'],
      updatedAt: _updatedAt,
      weeklyIndex: _week(4, Rating.good),
    ),
    Spot(
      id: 5,
      name: '사량도 옥동',
      regionGroupId: 103,
      regionName: '남해',
      rating: Rating.veryGood,
      waterTemp: 18.8,
      waveHeight: 0.3,
      windSpeed: 1.8,
      weather: '맑음',
      tideInfo: '4물 · 만조 11:50',
      sunriseSunset: '05:16 / 19:46',
      comment: '수온·물때 모두 최상, 올해 손꼽히는 출조 적기입니다.',
      hourlyForecast: const [60, 75, 85, 80, 72, 64],
      recommendedFish: const ['참돔', '감성돔', '볼락'],
      updatedAt: _updatedAt,
      weeklyIndex: _week(5, Rating.veryGood),
    ),
    Spot(
      id: 6,
      name: '구룡포 방파제',
      regionGroupId: 101,
      regionName: '동해',
      rating: Rating.bad,
      waterTemp: 16.8,
      waveHeight: 1.6,
      windSpeed: 8.4,
      weather: '비',
      tideInfo: '8물 · 간조 18:10',
      sunriseSunset: '05:09 / 19:40',
      comment: '너울이 높아 안전을 위해 출조를 권하지 않습니다.',
      hourlyForecast: const [30, 28, 25, 22, 20, 18],
      recommendedFish: const ['—'],
      updatedAt: _updatedAt,
      weeklyIndex: _week(6, Rating.bad),
    ),
    // 아래 둘은 KHOA 해역이 그대로 포인트가 된 예다 (서버 V14). 목에도 하나씩 둬야
    // 제주·동해 권역이 빈 채로 보이지 않는다.
    Spot(
      id: 7,
      name: '서귀포',
      regionGroupId: 104,
      regionName: '제주',
      rating: Rating.good,
      waterTemp: 21.3,
      waveHeight: 0.8,
      windSpeed: 4.2,
      weather: '맑음',
      tideInfo: '3물 · 만조 11:40',
      sunriseSunset: '05:22 / 19:31',
      comment: '파고 낮고 바람 잔잔해 갯바위 접근이 수월합니다.',
      hourlyForecast: const [48, 60, 72, 70, 62, 55],
      recommendedFish: const ['돌돔', '벵에돔', '참돔'],
      updatedAt: _updatedAt,
      weeklyIndex: _week(7, Rating.good),
    ),
    Spot(
      id: 8,
      name: '울릉도',
      regionGroupId: 101,
      regionName: '동해',
      rating: Rating.veryGood,
      waterTemp: 19.6,
      waveHeight: 0.5,
      windSpeed: 3.1,
      weather: '맑음',
      tideInfo: '4물 · 간조 15:05',
      sunriseSunset: '05:01 / 19:26',
      comment: '바람 약하고 파고 낮아 출조하기 아주 좋은 날입니다.',
      hourlyForecast: const [52, 68, 80, 78, 70, 61],
      recommendedFish: const ['돌돔', '벵에돔', '우럭'],
      updatedAt: _updatedAt,
      weeklyIndex: _week(8, Rating.veryGood),
    ),
  ];


  static final posts = <Post>[
    Post(
      id: 1,
      category: PostCategory.catchReport,
      title: '오늘 학리에서 감성돔 4짜 손맛!',
      summary: '새벽 물때에 입질 폭발했습니다. 다들 출조하세요~',
      authorNickname: '바다사나이',
      createdAt: _now.subtract(const Duration(hours: 2)),
      likeCount: 24,
      commentCount: 8,
      hasImage: true,
      regionName: '남해',
      boardKey: '남해',
    ),
    Post(
      id: 2,
      category: PostCategory.catchReport,
      title: '참돔 시즌 시작! 새벽 물때 강추',
      summary: '사량도 옥동 갯바위 자리 좋습니다. 채비는 가볍게.',
      authorNickname: '갯바위킹',
      createdAt: _now.subtract(const Duration(days: 1)),
      likeCount: 41,
      commentCount: 15,
      hasImage: true,
      regionName: '남해',
      boardKey: '남해',
    ),
    Post(
      id: 3,
      category: PostCategory.free,
      title: '초보도 잡았네요 ㅎㅎ 볼락 조황 좋아요',
      summary: '잔잔하고 수온 안정적이라 가족이랑 다녀왔어요.',
      authorNickname: '손맛중독',
      createdAt: _now.subtract(const Duration(hours: 5)),
      likeCount: 12,
      commentCount: 3,
      hasImage: false,
      regionName: '남해',
      boardKey: '남해',
    ),
    Post(
      id: 4,
      category: PostCategory.question,
      title: '영종도 우럭 포인트 추천 부탁드려요',
      summary: '주말에 처음 가보는데 선착장 근처 어떤가요?',
      authorNickname: '릴사랑',
      createdAt: _now.subtract(const Duration(days: 1)),
      likeCount: 5,
      commentCount: 9,
      hasImage: false,
      regionName: '서해',
      boardKey: '서해',
    ),
  ];

  // 시안 FAVS = ['부산 기장','통영 사량도','여수 돌산']
  static final profile = Profile(
    nickname: '바다러버',
    level: 7,
    // 아이콘은 전부 헤어라인 커스텀 세트로 그리므로 데이터에 이모지를 두지 않는다.
    levelTitle: '조사 Lv.7',
    catchCount: 22,
    postCount: 18,
    favoriteCount: 3,
    favoriteRegions: [regions[2], regions[0], regions[3]],
  );

  // ── 내부 ──────────────────────────────────────────────────────

  static final _now = DateTime.now();
  static final _updatedAt = _now.subtract(const Duration(minutes: 40));

  /// 목 모드의 주간 예보 — 오늘부터 7일.
  ///
  /// 실서버는 KHOA 응답을 그대로 저장하지만 목에는 그럴 것이 없다. 포인트 id 로 흐름을
  /// 어긋나게 해서 **화면이 다 같은 모양으로 보이지 않게** 한다. 값은 꾸며 낸 것이고,
  /// 목의 다른 값들과 성격이 같다.
  static List<DailyIndex> _week(int spotId, Rating today) {
    // 좋았다 나빠졌다 하는 한 주. 시작 지점만 포인트마다 민다.
    const flow = [Rating.normal, Rating.bad, Rating.bad, Rating.good,
                  Rating.veryGood, Rating.normal, Rating.bad];
    final from = DateTime(_now.year, _now.month, _now.day);

    return [
      for (var i = 0; i < 7; i++)
        DailyIndex(
          date: from.add(Duration(days: i)),
          // ⚠️ 첫 칸은 **그 포인트의 오늘 등급 그대로**여야 한다. 실서버는 둘이 같은
          //    KHOA 응답에서 나오므로 저절로 맞지만, 목에서 어긋나게 두면 지수 카드가
          //    `아주 좋음` 인데 주간 첫 칸은 빨강인 화면이 나온다.
          rating: i == 0 ? today : flow[(i + spotId) % flow.length],
          waveHeight: 0.4 + ((i + spotId) % 4) * 0.3,
          windSpeed: 3.0 + ((i + spotId * 2) % 5) * 1.6,
        ),
    ];
  }

}
