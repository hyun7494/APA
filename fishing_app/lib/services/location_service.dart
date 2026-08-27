import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// 기기 위치를 한 번 받아 온다.
///
/// 권한 흐름을 화면에 흩어 두지 않으려고 여기 모은다 — 흩어 두면 "거부했을 때 무엇을
/// 보여줄지" 가 자리마다 달라진다 ([requireLogin] 을 한 군데 모은 것과 같은 이유).
///
/// ⚠️ 실패를 예외로 던지지 않고 [LocationResult] 로 돌려준다. 위치 거부는 오류가 아니라
/// **사용자의 선택**이고, 화면은 그때 오류 상자가 아니라 안내 한 줄을 띄워야 한다.
abstract interface class LocationService {
  Future<LocationResult> current();
}

/// 위치를 받아 온 결과.
sealed class LocationResult {
  const LocationResult();
}

class LocationFound extends LocationResult {
  const LocationFound(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// 못 받아 왔다. [message] 는 **그대로 화면에 띄울 수 있는 한 줄**이다.
class LocationDenied extends LocationResult {
  const LocationDenied(this.message, {this.openSettings = false});

  final String message;

  /// 앱 설정을 열어 줘야 풀리는 상태인가 (영구 거부).
  final bool openSettings;
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<LocationResult> current() async {
    // 기기의 위치 기능 자체가 꺼져 있으면 권한을 물어도 소용이 없다.
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationDenied('기기의 위치 기능이 꺼져 있어요');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      // 여기서 다시 물어도 시스템이 대화상자를 안 띄운다. 설정으로 보내는 수밖에 없다.
      return const LocationDenied(
        '위치 권한이 꺼져 있어요. 설정에서 켜주세요',
        openSettings: true,
      );
    }
    if (permission == LocationPermission.denied) {
      return const LocationDenied('위치 권한이 필요해요');
    }

    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          // 낚시 포인트를 가까운 순으로 줄 세우는 데 미터 단위 정확도는 필요 없다.
          // 높은 정확도를 요구하면 실내에서 한참 걸리거나 아예 못 잡는다.
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LocationFound(p.latitude, p.longitude);
    } catch (_) {
      // 시간 초과·기기 오류가 여기로 온다. 사용자가 할 수 있는 일만 알려준다.
      return const LocationDenied('위치를 찾지 못했어요. 잠시 후 다시 시도해 주세요');
    }
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);
