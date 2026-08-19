import 'rating.dart';

/// 낚시 포인트 — `fishing_spots` (기획서 3-1).
///
/// GET /fishing/spots?regionGroupId=  ·  GET /fishing/spots/{id}
class Spot {
  const Spot({
    required this.id,
    required this.name,
    required this.regionGroupId,
    required this.regionName,
    required this.rating,
    required this.waterTemp,
    required this.waveHeight,
    required this.windSpeed,
    required this.weather,
    required this.tideInfo,
    required this.sunriseSunset,
    required this.comment,
    required this.hourlyForecast,
    required this.recommendedFish,
    required this.updatedAt,
  });

  final int id;

  /// "기장 학리"
  final String name;

  final int regionGroupId;

  /// 목록·상세에서 그대로 보여줄 지역 그룹명 ("부산 기장")
  final String regionName;

  final Rating rating;

  /// 수온 ℃
  final double waterTemp;

  /// 파고 m
  final double waveHeight;

  /// 풍속 ㎧
  final double windSpeed;

  /// 맑음 / 구름조금 / 흐림 / 비
  final String weather;

  /// "5물 · 만조 13:20"
  final String tideInfo;

  /// "05:11 / 19:42"
  final String sunriseSunset;

  final String comment;

  /// 06/09/12/15/18/21시 6구간 조황 예상치(%) — 상세 화면 막대그래프
  final List<int> hourlyForecast;

  /// ["감성돔", "벵에돔", "농어"]
  final List<String> recommendedFish;

  /// 배치 갱신 시각
  final DateTime updatedAt;

  /// 막대그래프 x축 라벨 — hourlyForecast와 인덱스가 대응한다.
  static const hourLabels = ['06시', '09시', '12시', '15시', '18시', '21시'];

  factory Spot.fromJson(Map<String, dynamic> json) => Spot(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    regionGroupId: (json['regionGroupId'] as num?)?.toInt() ?? 0,
    regionName: json['regionName'] as String? ?? '',
    rating: Rating.fromCode(json['rating'] as String?),
    waterTemp: (json['waterTemp'] as num?)?.toDouble() ?? 0,
    waveHeight: (json['waveHeight'] as num?)?.toDouble() ?? 0,
    windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 0,
    weather: json['weather'] as String? ?? '-',
    tideInfo: json['tideInfo'] as String? ?? '-',
    sunriseSunset: json['sunriseSunset'] as String? ?? '-',
    comment: json['comment'] as String? ?? '',
    hourlyForecast:
        (json['hourlyForecast'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        const [],
    recommendedFish:
        (json['recommendedFish'] as List?)?.cast<String>().toList() ?? const [],
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'regionGroupId': regionGroupId,
    'regionName': regionName,
    'rating': rating.code,
    'waterTemp': waterTemp,
    'waveHeight': waveHeight,
    'windSpeed': windSpeed,
    'weather': weather,
    'tideInfo': tideInfo,
    'sunriseSunset': sunriseSunset,
    'comment': comment,
    'hourlyForecast': hourlyForecast,
    'recommendedFish': recommendedFish,
    'updatedAt': updatedAt.toIso8601String(),
  };
}
