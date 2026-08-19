import 'rating.dart';

/// 지역 그룹 — `fishing_regions` (기획서 3-1).
///
/// GET /fishing/regions, GET /fishing/regions/search?q=
class RegionGroup {
  const RegionGroup({
    required this.id,
    required this.name,
    required this.area,
    this.previewRating,
    this.previewWaterTemp,
    this.spotCount,
  });

  final int id;

  /// "부산 기장"
  final String name;

  /// "부산광역시"
  final String area;

  /// 지역 검색 화면의 그룹별 대표 등급 미리보기 (목록 API에서만 내려옴)
  final Rating? previewRating;

  /// 그룹별 대표 수온 미리보기 ℃
  final double? previewWaterTemp;

  /// 그룹에 속한 포인트 수
  final int? spotCount;

  factory RegionGroup.fromJson(Map<String, dynamic> json) => RegionGroup(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    area: json['area'] as String? ?? '',
    previewRating: json['previewRating'] == null
        ? null
        : Rating.fromCode(json['previewRating'] as String),
    previewWaterTemp: (json['previewWaterTemp'] as num?)?.toDouble(),
    spotCount: (json['spotCount'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'area': area,
    'previewRating': previewRating?.code,
    'previewWaterTemp': previewWaterTemp,
    'spotCount': spotCount,
  };
}
