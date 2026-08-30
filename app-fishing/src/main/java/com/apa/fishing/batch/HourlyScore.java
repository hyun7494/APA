package com.apa.fishing.batch;

/**
 * 한 시간대의 조황 예상치(0~100). 상세 화면 막대그래프의 높이가 이 값이다.
 *
 * <p><b>{@link RatingRule} 과 같은 임계값에서 나온다.</b> 따로 만들면 "등급은 나쁨인데
 * 막대는 높은" 날이 생긴다 — 같은 카드 안에 두 숫자가 서로를 반박하게 된다.
 * 규칙이 바뀌면 두 곳을 같이 고칠 것.
 *
 * <p>임계값과 마찬가지로 이 계수도 <b>출발점</b>이지 확정된 기준이 아니다.
 * 확인용으로 {@link RatingRule} 이 등급 경계로 삼은 네 지점을 넣어 보면
 * 학리 75 · 대변항 64 · 영종도 42 · 구룡포 5 로 등급 순서와 어긋나지 않는다.
 */
public final class HourlyScore {

    private HourlyScore() {
    }

    /** 풍속 1㎧ 당 깎는 점수. 8㎧(= 나쁨 경계)에서 48점이 빠진다. */
    private static final double WIND_PENALTY_PER_MS = 6.0;

    /** 파고 1m 당 깎는 점수. 1.5m(= 나쁨 경계)에서 45점이 빠진다. */
    private static final double WAVE_PENALTY_PER_M = 30.0;

    /** 비·눈이 오면 일괄로 깎는다. {@link RatingRule} 이 한 단계 낮추는 것과 같은 자리다. */
    private static final double PRECIPITATION_PENALTY = 15.0;

    /**
     * 0 과 100 은 쓰지 않는다. 막대가 아예 없거나 꽉 찬 그래프는 <b>데이터가 없는 것</b>과
     * 구별되지 않는다 — 지금 45곳이 겪던 문제가 정확히 그거였다.
     */
    private static final int MIN = 5;
    private static final int MAX = 95;

    /**
     * @param windSpeed  ㎧. <b>필수다</b> — 이것도 없으면 시간대를 평가할 근거가 없다
     * @param waveHeight m. 내륙 격자에는 WAV 카테고리가 없어 null 로 온다. 그때는 풍속만 본다
     * @param weather    맑음/흐림/비… 표기. null 이면 강수 없음으로 본다
     * @return 0~100 사이의 조황 예상치. {@code windSpeed} 가 null 이면 {@code null}
     */
    public static Integer of(Double windSpeed, Double waveHeight, String weather) {
        if (windSpeed == null) {
            return null;
        }

        double score = 100.0
                - windSpeed * WIND_PENALTY_PER_MS
                - (waveHeight == null ? 0.0 : waveHeight * WAVE_PENALTY_PER_M)
                - (RatingRule.isPrecipitation(weather) ? PRECIPITATION_PENALTY : 0.0);

        return (int) Math.round(Math.clamp(score, MIN, MAX));
    }
}
