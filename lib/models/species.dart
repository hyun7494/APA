import 'package:flutter/material.dart';

/// 서식지 — `fishing_species.habitat`
enum Habitat {
  sea('SEA', '바다'),
  fresh('FRESH', '민물');

  const Habitat(this.code, this.label);

  final String code;
  final String label;

  static Habitat fromCode(String? code) =>
      Habitat.values.firstWhere((h) => h.code == code, orElse: () => Habitat.sea);
}

/// 희귀 등급 — `fishing_species.rarity`
///
/// 기획서 3-2: 초기엔 어종 마스터에 수동 지정한다(등록 빈도 데이터가 쌓이기 전).
enum Rarity {
  common('COMMON', '일반'),
  uncommon('UNCOMMON', '드묾'),
  rare('RARE', '희귀');

  const Rarity(this.code, this.label);

  final String code;
  final String label;

  /// 도감 칸에 골드 테두리를 두르는지
  bool get isRare => this == Rarity.rare;

  static Rarity fromCode(String? code) =>
      Rarity.values.firstWhere((r) => r.code == code, orElse: () => Rarity.common);
}

/// 어종 마스터 — `fishing_species` (기획서 3-2).
///
/// 도감의 뼈대다. 관리자만 수정하는 시드 데이터이며 사용자 입력으로 늘지 않는다.
///
/// GET /fishing/species · GET /fishing/species/{id}
@immutable
class Species {
  const Species({
    required this.id,
    required this.name,
    required this.habitat,
    required this.rarity,
    required this.displayOrder,
    this.nameSci = '',
    this.minLegalSize,
    this.closedSeason,
    this.season,
    this.description = '',
    this.illustPath,
    this.isActive = true,
  });

  final int id;

  /// "감성돔"
  final String name;

  /// "Acanthopagrus schlegelii" — 선택
  final String nameSci;

  final Habitat habitat;
  final Rarity rarity;

  /// 포획금지체장 cm. 「수산자원관리법 시행령」 기준이며,
  /// 앱은 위법 여부를 판정하지 않고 정보로만 노출한다 (기획서 7장).
  final double? minLegalSize;

  /// "12/01~01/31"
  final String? closedSeason;

  /// "9월 ~ 12월" — 제철 (도감 상세 표)
  final String? season;

  final String description;

  /// 컬러 일러스트 경로. 에셋 확보 전에는 null이고,
  /// 도감 칸은 사용자가 등록한 인증샷을 표지로 쓴다.
  final String? illustPath;

  final int displayOrder;
  final bool isActive;

  factory Species.fromJson(Map<String, dynamic> json) => Species(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    nameSci: json['nameSci'] as String? ?? '',
    habitat: Habitat.fromCode(json['habitat'] as String?),
    rarity: Rarity.fromCode(json['rarity'] as String?),
    minLegalSize: (json['minLegalSize'] as num?)?.toDouble(),
    closedSeason: json['closedSeason'] as String?,
    season: json['season'] as String?,
    description: json['description'] as String? ?? '',
    illustPath: json['illustPath'] as String?,
    displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    isActive: json['isActive'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nameSci': nameSci,
    'habitat': habitat.code,
    'rarity': rarity.code,
    'minLegalSize': minLegalSize,
    'closedSeason': closedSeason,
    'season': season,
    'description': description,
    'illustPath': illustPath,
    'displayOrder': displayOrder,
    'isActive': isActive,
  };
}

/// 도감 한 칸 — 어종 마스터 + 그 어종에 대한 내 획득 상태.
///
/// GET /fishing/me/collection 이 이 형태로 내려온다. 서버가 없을 때는
/// 어종 목록과 내 조과 기록을 클라이언트에서 합쳐 만든다.
@immutable
class CollectionEntry {
  const CollectionEntry({
    required this.species,
    this.catchCount = 0,
    this.bestLengthCm,
    this.coverPhotoUrl,
    this.firstCaughtAt,
  });

  final Species species;

  /// 이 어종을 등록한 횟수. 0이면 미등록 칸.
  final int catchCount;

  /// 내 최고 기록 (cm)
  final double? bestLengthCm;

  /// 도감 칸 표지로 쓸 인증샷 — 최고 기록의 사진
  final String? coverPhotoUrl;

  final DateTime? firstCaughtAt;

  /// 기획서 3-3: 해당 어종 레코드가 1건이라도 있으면 획득으로 본다.
  bool get owned => catchCount > 0;

  /// 도감 칸의 세 가지 상태 (시안 "도감 칸의 세 가지 상태")
  SpeciesTileState get state => switch ((owned, species.rarity.isRare)) {
    (false, _) => SpeciesTileState.locked,
    (true, true) => SpeciesTileState.rare,
    (true, false) => SpeciesTileState.registered,
  };

  factory CollectionEntry.fromJson(Map<String, dynamic> json) => CollectionEntry(
    species: Species.fromJson(json['species'] as Map<String, dynamic>),
    catchCount: (json['catchCount'] as num?)?.toInt() ?? 0,
    bestLengthCm: (json['bestLengthCm'] as num?)?.toDouble(),
    coverPhotoUrl: json['coverPhotoUrl'] as String?,
    firstCaughtAt: DateTime.tryParse(json['firstCaughtAt'] as String? ?? ''),
  );
}

/// 도감 칸 렌더 상태.
///
/// 미등록 칸은 어종 이름을 `???`로 가린다 — 뭐가 나올지 모른다는 것 자체가
/// 수집 동기가 된다는 시안의 판단을 따랐다.
enum SpeciesTileState { registered, rare, locked }

/// 도감 진행도 요약 — 홈 카드와 도감 상단 카드가 공유한다.
@immutable
class CollectionSummary {
  const CollectionSummary({
    required this.total,
    required this.owned,
    required this.rareOwned,
    this.newThisMonth = 0,
  });

  /// 전체 어종 수 (분모)
  final int total;

  /// 등록한 어종 수
  final int owned;

  /// 그중 희귀 등급 수
  final int rareOwned;

  /// 이번 달 새로 등록한 종 수
  final int newThisMonth;

  /// 일반 등급 등록 수
  int get commonOwned => owned - rareOwned;

  int get locked => total - owned;

  double get ratio => total == 0 ? 0 : owned / total;

  /// 54% 처럼 표시할 정수 퍼센트
  int get percent => (ratio * 100).round();
}
