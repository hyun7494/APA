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

    /**
     * 강수가 있으면 한 단계 낮춘다.
     *
     * <p>'소나기'가 따로 있는 이유: 기상청 PTY 코드 4의 표기가 '소나기'인데 여기엔 '비'도 '눈'도
     * 안 들어간다. 부분 문자열만 보면 <b>소나기가 조용히 맑은 날 취급</b>된다.
     * 시드에는 없던 값이라 Step 6 배치가 붙기 전까지 드러나지 않던 구멍이다.
     */
    private static final String[] PRECIPITATION = {"비", "눈", "소나기"};

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
        if (weather == null) {
            return false;
        }
        for (String token : PRECIPITATION) {
            if (weather.contains(token)) {
                return true;
            }
        }
        return false;
    }

    private static Rating downgrade(Rating rating) {
        return switch (rating) {
            case VERY_GOOD -> Rating.GOOD;
            case GOOD -> Rating.NORMAL;
            case NORMAL, BAD -> Rating.BAD;
        };
    }
}
