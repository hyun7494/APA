package com.apa.fishing.batch;

import com.apa.fishing.domain.Rating;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/** 시안 6개 포인트의 값을 넣으면 시안과 같은 등급이 나와야 한다 — 임계값을 역산한 근거다. */
class RatingRuleTest {

    @Test
    @DisplayName("시드 포인트의 파고·풍속이 시안 등급을 재현한다")
    void reproducesSeedRatings() {
        assertThat(RatingRule.evaluate(0.4, 2.1, "맑음")).isEqualTo(Rating.VERY_GOOD);   // 기장 학리
        assertThat(RatingRule.evaluate(0.6, 3.0, "구름조금")).isEqualTo(Rating.GOOD);    // 대변항
        assertThat(RatingRule.evaluate(0.9, 5.2, "흐림")).isEqualTo(Rating.NORMAL);      // 영종도
        assertThat(RatingRule.evaluate(0.5, 2.6, "맑음")).isEqualTo(Rating.GOOD);        // 돌산
        assertThat(RatingRule.evaluate(0.3, 1.8, "맑음")).isEqualTo(Rating.VERY_GOOD);   // 사량도
        assertThat(RatingRule.evaluate(1.6, 8.4, "비")).isEqualTo(Rating.BAD);           // 구룡포
    }

    @Test
    @DisplayName("파고와 풍속 중 나쁜 쪽을 따른다")
    void takesTheWorseOfTheTwo() {
        // 파고는 아주 좋은데 바람이 세면 좋은 날이 아니다.
        assertThat(RatingRule.evaluate(0.1, 8.5, "맑음")).isEqualTo(Rating.BAD);
        assertThat(RatingRule.evaluate(1.6, 0.5, "맑음")).isEqualTo(Rating.BAD);
    }

    @Test
    @DisplayName("비·눈이면 한 단계 낮춘다")
    void badWeatherDowngrades() {
        assertThat(RatingRule.evaluate(0.4, 2.1, "비")).isEqualTo(Rating.GOOD);
        assertThat(RatingRule.evaluate(0.6, 3.0, "눈")).isEqualTo(Rating.NORMAL);
        assertThat(RatingRule.evaluate(0.9, 5.2, "비")).isEqualTo(Rating.BAD);
        // 이미 BAD 면 더 내려갈 곳이 없다.
        assertThat(RatingRule.evaluate(2.0, 9.0, "비")).isEqualTo(Rating.BAD);
    }

    @Test
    @DisplayName("기상청 PTY 표기를 그대로 넣어도 강수로 인식한다")
    void recognisesKmaPrecipitationLabels() {
        // '소나기'에는 '비'도 '눈'도 안 들어간다 — 부분 문자열만 보면 맑은 날로 새어나간다.
        assertThat(RatingRule.evaluate(0.4, 2.1, "소나기")).isEqualTo(Rating.GOOD);
        assertThat(RatingRule.evaluate(0.4, 2.1, "비/눈")).isEqualTo(Rating.GOOD);
        // 강수가 아닌 표기는 등급을 안 건드린다.
        assertThat(RatingRule.evaluate(0.4, 2.1, "구름많음")).isEqualTo(Rating.VERY_GOOD);
        assertThat(RatingRule.evaluate(0.4, 2.1, "흐림")).isEqualTo(Rating.VERY_GOOD);
    }

    @Test
    @DisplayName("weather 가 null 이어도 터지지 않는다 — 공공 API 는 일부 필드를 빼먹기도 한다")
    void nullWeatherIsSafe() {
        assertThat(RatingRule.evaluate(0.4, 2.1, null)).isEqualTo(Rating.VERY_GOOD);
    }
}
