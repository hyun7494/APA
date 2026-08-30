package com.apa.fishing.batch;

import com.apa.fishing.domain.Rating;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 막대그래프 높이. 키 없이 도는 순수 함수라 {@link RatingRuleTest} 와 같은 자리에 둔다.
 *
 * <p>여기서 지키려는 건 절대값이 아니라 <b>등급과 어긋나지 않는다</b>는 것이다.
 * 같은 카드 안에서 배지는 '나쁨'인데 막대가 제일 높으면 둘 다 못 믿게 된다.
 */
class HourlyScoreTest {

    /** {@link RatingRule} 이 등급 경계로 삼은 네 지점. 파고 m, 풍속 ㎧ 순. */
    private static final double[] HAKRI = {0.4, 2.1};      // VERY_GOOD
    private static final double[] DAEBYEON = {0.6, 3.0};   // GOOD
    private static final double[] YEONGJONG = {0.9, 5.2};  // NORMAL
    private static final double[] GURYONGPO = {1.6, 8.4};  // BAD

    private static int score(double[] point) {
        return HourlyScore.of(point[1], point[0], "맑음");
    }

    @Test
    @DisplayName("★ 등급이 좋은 지점일수록 점수가 높다 — 배지와 그래프가 반대로 가면 안 된다")
    void agreesWithRatingOrder() {
        assertThat(RatingRule.evaluate(HAKRI[0], HAKRI[1], "맑음")).isEqualTo(Rating.VERY_GOOD);
        assertThat(RatingRule.evaluate(GURYONGPO[0], GURYONGPO[1], "맑음")).isEqualTo(Rating.BAD);

        assertThat(score(HAKRI))
                .isGreaterThan(score(DAEBYEON))
                .isGreaterThan(score(YEONGJONG))
                .isGreaterThan(score(GURYONGPO));
        assertThat(score(DAEBYEON)).isGreaterThan(score(YEONGJONG));
        assertThat(score(YEONGJONG)).isGreaterThan(score(GURYONGPO));
    }

    @Test
    @DisplayName("★ 0 도 100 도 안 나온다 — 0 은 '값 없음' 과 구별되지 않는다")
    void staysInsideBand() {
        assertThat(HourlyScore.of(0.0, 0.0, "맑음")).isBetween(5, 95);
        assertThat(HourlyScore.of(30.0, 9.0, "비")).isBetween(5, 95);
    }

    @Test
    @DisplayName("비가 오면 같은 바람·파도라도 낮아진다 — RatingRule 이 한 단계 낮추는 것과 같다")
    void precipitationLowersScore() {
        assertThat(HourlyScore.of(3.0, 0.5, "비"))
                .isLessThan(HourlyScore.of(3.0, 0.5, "맑음"));
        assertThat(HourlyScore.of(3.0, 0.5, "소나기"))
                .isLessThan(HourlyScore.of(3.0, 0.5, "흐림"));
    }

    @Test
    @DisplayName("파고가 없으면(내륙 격자) 풍속만으로 낸다 — 0m 로 메우지 않는다")
    void survivesMissingWave() {
        assertThat(HourlyScore.of(3.0, null, "맑음")).isNotNull();
    }

    @Test
    @DisplayName("★ 풍속조차 없으면 점수를 만들지 않는다")
    void refusesWithoutWind() {
        assertThat(HourlyScore.of(null, 0.5, "맑음")).isNull();
    }
}
