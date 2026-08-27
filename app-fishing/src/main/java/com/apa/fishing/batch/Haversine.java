package com.apa.fishing.batch;

/**
 * 두 좌표 사이 거리(km). 내 위치에서 가까운 포인트를 고를 때 쓴다.
 *
 * <p>지구를 구로 보고 재는 식이라 수백 m 오차가 있지만, "가까운 순으로 줄 세우기" 에는
 * 넉넉하다. 정밀한 측지 거리가 필요해지면 그때 바꿀 것.
 *
 * <p>{@link GridConverter} 옆에 둔 이유는 둘 다 <b>좌표를 다루는 순수 함수</b>라
 * 키 없이 테스트되기 때문이다.
 */
public final class Haversine {

    private Haversine() {
    }

    private static final double EARTH_RADIUS_KM = 6371.0088;

    public static double km(double lat1, double lon1, double lat2, double lon2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);

        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);

        return 2 * EARTH_RADIUS_KM * Math.asin(Math.min(1.0, Math.sqrt(a)));
    }
}
