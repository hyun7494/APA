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
    this.weeklyIndex = const [],
    this.distanceKm,
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

  /// 내 위치에서 몇 km 인지. **위치 검색일 때만** 채워지고 평소에는 null 이다.
  final double? distanceKm;

  /// 오늘부터의 예보. 서버가 KHOA 해역을 못 붙인 포인트(영종도)는 **빈 목록**이다.
  final List<DailyIndex> weeklyIndex;

  /// 막대그래프 x축 라벨 — hourlyForecast와 인덱스가 대응한다.
  static const hourLabels = ['06시', '09시', '12시', '15시', '18시', '21시'];

  /// 거리만 갈아 끼운 사본. 목이 순서를 만들 때 쓴다 — 실서버는 서버가 채워 준다.
  Spot withDistance(double km) => Spot(
    id: id,
    name: name,
    regionGroupId: regionGroupId,
    regionName: regionName,
    rating: rating,
    waterTemp: waterTemp,
    waveHeight: waveHeight,
    windSpeed: windSpeed,
    weather: weather,
    tideInfo: tideInfo,
    sunriseSunset: sunriseSunset,
    comment: comment,
    hourlyForecast: hourlyForecast,
    recommendedFish: recommendedFish,
    updatedAt: updatedAt,
    weeklyIndex: weeklyIndex,
    distanceKm: km,
  );

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
    distanceKm: (json['distanceKm'] as num?)?.toDouble(),
    weeklyIndex:
        (json['weeklyIndex'] as List?)
            ?.map((e) => DailyIndex.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
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
    'weeklyIndex': [for (final day in weeklyIndex) day.toJson()],
    'distanceKm': distanceKm,
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// 주간 예보의 하루 (계약서 3-3, V13).
///
/// 새 데이터 소스가 아니다 — 오늘 지수를 받아 오던 **같은 응답에 들어 있던 나머지 날짜**다.
/// 서버가 버리지 않고 저장하기 시작했을 뿐이다.
class DailyIndex {
  const DailyIndex({
    required this.date,
    required this.rating,
    this.waveHeight,
    this.windSpeed,
  });

  final DateTime date;
  final Rating rating;

  /// 그날 최대 파고. **null 이 정상**이고 0 이 아니다 — 안전 수치라 결측을
  /// 0 으로 그리면 "잔잔한 날"로 위장된다.
  final double? waveHeight;
  final double? windSpeed;

  factory DailyIndex.fromJson(Map<String, dynamic> json) => DailyIndex(
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    rating: Rating.fromCode(json['rating'] as String?),
    waveHeight: (json['waveHeight'] as num?)?.toDouble(),
    windSpeed: (json['windSpeed'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    // 서버가 주는 형식과 같게 — 날짜만이고 시각은 없다.
    'date': '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
    'rating': rating.code,
    'waveHeight': waveHeight,
    'windSpeed': windSpeed,
  };
}
