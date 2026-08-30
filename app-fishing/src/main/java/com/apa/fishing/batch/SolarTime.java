package com.apa.fishing.batch;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;

/**
 * 좌표와 날짜로 일출·일몰을 낸다. <b>공공 API 를 부르지 않는다</b> — 천문 계산이라
 * 키도 네트워크도 필요 없고, 그래서 51곳 전부에서 똑같이 나온다.
 *
 * <p>{@link GridConverter} · {@link Haversine} 와 같은 자리다: 키 없이 도는 순수 함수.
 *
 * <p>NOAA 의 표준 근사식이다. 대기 굴절을 -0.833° 로 잡는 통상적인 정의를 쓰며,
 * 오차는 분 단위다. <b>출조 시각을 가늠하는 용도</b>지 항해용 정밀도가 아니다 —
 * 상세 화면의 면책 문구가 덮는 범위 안에 있다.
 */
public final class SolarTime {

    private SolarTime() {
    }

    /** 지구 자전축 기울기(도). */
    private static final double OBLIQUITY = 23.4397;

    /** 해가 "떴다" 고 보는 고도. 태양 반지름과 대기 굴절을 합쳐 지평선 아래 0.833° 다. */
    private static final double SUN_ALTITUDE = -0.833;

    private static final double J2000 = 2451545.0;

    /** 극지방에서 해가 종일 떠 있거나 종일 지지 않는 날. 한국 위도에서는 나오지 않는다. */
    private record Times(LocalTime sunrise, LocalTime sunset) {
    }

    /**
     * 상세 화면에 그대로 들어가는 {@code "05:09 / 19:40"} 문자열을 만든다.
     *
     * @param latitude  북위 +
     * @param longitude 동경 +
     * @param zone      표시할 시간대. 한국이면 {@code Asia/Seoul}
     * @return 백야·극야라 해가 뜨거나 지지 않으면 {@code null}. 화면은 그때 값을 안 바꾼다
     */
    public static String describe(double latitude, double longitude, LocalDate date, ZoneId zone) {
        Times times = of(latitude, longitude, date, zone);
        return times == null
                ? null
                : "%s / %s".formatted(format(times.sunrise()), format(times.sunset()));
    }

    private static String format(LocalTime time) {
        return "%02d:%02d".formatted(time.getHour(), time.getMinute());
    }

    private static Times of(double latitude, double longitude, LocalDate date, ZoneId zone) {
        // 그 날짜의 정오를 기준으로 잡는다. 자정을 쓰면 날짜 경계에서 하루가 밀린다.
        double n = Math.ceil(julianDay(date) - J2000 + 0.0008);
        double meanSolarNoon = n - longitude / 360.0;

        double meanAnomaly = mod360(357.5291 + 0.98560028 * meanSolarNoon);
        double center = 1.9148 * sin(meanAnomaly)
                + 0.0200 * sin(2 * meanAnomaly)
                + 0.0003 * sin(3 * meanAnomaly);
        double eclipticLongitude = mod360(meanAnomaly + center + 180 + 102.9372);

        double solarTransit = J2000 + meanSolarNoon
                + 0.0053 * sin(meanAnomaly)
                - 0.0069 * sin(2 * eclipticLongitude);

        double declinationSin = sin(eclipticLongitude) * sin(OBLIQUITY);
        double declinationCos = Math.cos(Math.asin(declinationSin));

        double hourAngleCos = (sin(SUN_ALTITUDE) - sin(latitude) * declinationSin)
                / (cos(latitude) * declinationCos);
        if (hourAngleCos < -1 || hourAngleCos > 1) {
            return null;                     // 백야·극야
        }
        double hourAngle = Math.toDegrees(Math.acos(hourAngleCos));

        return new Times(
                toLocalTime(solarTransit - hourAngle / 360.0, zone),
                toLocalTime(solarTransit + hourAngle / 360.0, zone));
    }

    /** 그레고리력 → 율리우스일. 그 날 정오(UT) 기준이다. */
    private static double julianDay(LocalDate date) {
        return date.toEpochDay() + 2440588.0;
    }

    private static LocalTime toLocalTime(double julian, ZoneId zone) {
        // 율리우스일의 소수부는 정오부터의 비율이다 (.0 이 정오, .5 가 자정)
        long epochMillis = Math.round((julian - 2440587.5) * 86_400_000.0);
        return java.time.Instant.ofEpochMilli(epochMillis).atZone(zone).toLocalTime();
    }

    private static double mod360(double degrees) {
        double result = degrees % 360.0;
        return result < 0 ? result + 360.0 : result;
    }

    private static double sin(double degrees) {
        return Math.sin(Math.toRadians(degrees));
    }

    private static double cos(double degrees) {
        return Math.cos(Math.toRadians(degrees));
    }
}
