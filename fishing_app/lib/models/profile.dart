import 'region_group.dart';

/// 마이페이지 — GET /fishing/me/profile (기획서 4-2).
///
/// 계정 자체는 APA auth-service가 소유하고, 여기 통계는 app-fishing이 집계한다.
///
/// Rev 2에서 `zodiac`(띠 설정)이 빠졌다 — 운세 전용 필드라 운세를 되살릴 때
/// 함께 복구한다.
class Profile {
  const Profile({
    required this.nickname,
    required this.level,
    required this.catchCount,
    required this.postCount,
    required this.favoriteCount,
    required this.favoriteRegions,
    this.levelTitle = '',
  });

  final String nickname;

  /// 레벨 숫자
  final int level;

  /// "조사 Lv.7" 같은 레벨 호칭
  final String levelTitle;

  /// 조과 기록 수 (Rev 1의 `tripCount`를 대체한다)
  final int catchCount;

  /// 작성글 수
  final int postCount;

  /// 즐겨찾기 수
  final int favoriteCount;

  /// 즐겨찾는 지역 칩
  final List<RegionGroup> favoriteRegions;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    nickname: json['nickname'] as String? ?? '조사님',
    level: (json['level'] as num?)?.toInt() ?? 1,
    levelTitle: json['levelTitle'] as String? ?? '',
    catchCount: (json['catchCount'] as num?)?.toInt() ?? 0,
    postCount: (json['postCount'] as num?)?.toInt() ?? 0,
    favoriteCount: (json['favoriteCount'] as num?)?.toInt() ?? 0,
    favoriteRegions:
        (json['favoriteRegions'] as List?)
            ?.map((e) => RegionGroup.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );

  Map<String, dynamic> toJson() => {
    'nickname': nickname,
    'level': level,
    'levelTitle': levelTitle,
    'catchCount': catchCount,
    'postCount': postCount,
    'favoriteCount': favoriteCount,
    'favoriteRegions': favoriteRegions.map((e) => e.toJson()).toList(),
  };
}
