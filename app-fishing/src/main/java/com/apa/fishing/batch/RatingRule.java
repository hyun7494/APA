package com.apa.fishing.batch;

import com.apa.fishing.domain.Rating;

/**
 * 파고·풍속 기반 4단계 지수 산출 (기획서 4-3).
 *
 * <p>임계값은 시안 데이터를 역산해 맞춘 <b>출발점</b>이다. 실제 관측값을 보면서 조정할 영역이지,
 * 확정된 기준이 아니다.
 *
 * <p>⚠️ 안전 관련이라 프론트 상세 화면에 면책 문구가 고정 노출돼 있다
 * ("참고용 정보이며 실제 출조 여부는 현장 상황을 확인하세요"). 지우지 말 것.
 */
public final class RatingRule {

    private RatingRule() {
    }

    /** 비·눈이면 한 단계 낮춘다. */
    private static final String RAIN = "비";
    private static final String SNOW = "눈";

    public static Rating evaluate(double waveHeight, double windSpeed, String weather) {
        Rating base = byWaveAndWind(waveHeight, windSpeed);
        return isBadWeather(weather) ? downgrade(base) : base;
    }

    private static Rating byWaveAndWind(double waveHeight, double windSpeed) {
        if (waveHeight >= 1.5 || windSpeed >= 8.0) {
            return Rating.BAD;        // 구룡포 1.6m / 8.4㎧
        }
        if (waveHeight >= 0.8 || windSpeed >= 5.0) {
            return Rating.NORMAL;     // 영종도 0.9m / 5.2㎧
        }
        if (waveHeight >= 0.5 || windSpeed >= 2.5) {
            return Rating.GOOD;       // 대변항 0.6m / 3.0㎧
        }
        return Rating.VERY_GOOD;      // 학리 0.4m / 2.1㎧
    }

    private static boolean isBadWeather(String weather) {
        return weather != null && (weather.contains(RAIN) || weather.contains(SNOW));
    }

    private static Rating downgrade(Rating rating) {
        return switch (rating) {
            case VERY_GOOD -> Rating.GOOD;
            case GOOD -> Rating.NORMAL;
            case NORMAL, BAD -> Rating.BAD;
        };
    }
}
