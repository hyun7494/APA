package com.apa.fishing.batch;

/**
 * 위경도 → 기상청 격자(nx, ny) 변환. 단기예보는 위경도를 받지 않는다.
 *
 * <p>기상청이 배포하는 Lambert Conformal Conic 변환식을 그대로 옮긴 것이다.
 * 상수를 손대면 전국이 어긋나므로 건드리지 말 것.
 *
 * <p>포인트가 6개뿐이라 런타임 변환 대신 <b>한 번 계산해 DB에 저장</b>한다
 * (스키마의 {@code grid_nx}, {@code grid_ny}). 이 클래스는 그 값을 만들 때와
 * 포인트를 추가할 때 쓴다.
 */
public final class GridConverter {

    private GridConverter() {
    }

    private static final double RE = 6371.00877;   // 지구 반경(km)
    private static final double GRID = 5.0;        // 격자 간격(km)
    private static final double SLAT1 = 30.0;      // 투영 위도 1
    private static final double SLAT2 = 60.0;      // 투영 위도 2
    private static final double OLON = 126.0;      // 기준점 경도
    private static final double OLAT = 38.0;       // 기준점 위도
    private static final double XO = 43;           // 기준점 X 격자
    private static final double YO = 136;          // 기준점 Y 격자

    private static final double DEGRAD = Math.PI / 180.0;

    public record Grid(int nx, int ny) {
    }

    public static Grid toGrid(double latitude, double longitude) {
        double re = RE / GRID;
        double slat1 = SLAT1 * DEGRAD;
        double slat2 = SLAT2 * DEGRAD;
        double olon = OLON * DEGRAD;
        double olat = OLAT * DEGRAD;

        double sn = Math.tan(Math.PI * 0.25 + slat2 * 0.5) / Math.tan(Math.PI * 0.25 + slat1 * 0.5);
        sn = Math.log(Math.cos(slat1) / Math.cos(slat2)) / Math.log(sn);

        double sf = Math.tan(Math.PI * 0.25 + slat1 * 0.5);
        sf = Math.pow(sf, sn) * Math.cos(slat1) / sn;

        double ro = Math.tan(Math.PI * 0.25 + olat * 0.5);
        ro = re * sf / Math.pow(ro, sn);

        double ra = Math.tan(Math.PI * 0.25 + latitude * DEGRAD * 0.5);
        ra = re * sf / Math.pow(ra, sn);

        double theta = longitude * DEGRAD - olon;
        if (theta > Math.PI) {
            theta -= 2.0 * Math.PI;
        }
        if (theta < -Math.PI) {
            theta += 2.0 * Math.PI;
        }
        theta *= sn;

        int nx = (int) Math.floor(ra * Math.sin(theta) + XO + 0.5);
        int ny = (int) Math.floor(ro - ra * Math.cos(theta) + YO + 0.5);
        return new Grid(nx, ny);
    }
}
