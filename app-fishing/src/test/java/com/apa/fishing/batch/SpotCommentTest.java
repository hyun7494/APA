package com.apa.fishing.batch;

import com.apa.fishing.domain.Rating;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 코멘트는 화면 3곳(홈·카드·상세)에 그대로 뜬다. 문구가 등급과 어긋나면 바로 눈에 띈다.
 */
class SpotCommentTest {

    @Test
    @DisplayName("등급보다 기상이 험하면 수치를 박아 경고한다")
    void warnsWithConcreteNumbers() {
        String comment = SpotComment.describe(Rating.NORMAL, 0.8, 8.3, "흐림");

        // "바람이 셉니다" 같은 문구는 판단 근거가 못 된다. 실제 값을 준다.
        assertThat(comment).contains("8.3").contains("0.8").contains("강풍");
    }

    @Test
    @DisplayName("기상이 잔잔하면 경고를 붙이지 않는다 — 매번 붙으면 아무도 안 읽는다")
    void staysQuietWhenCalm() {
        String comment = SpotComment.describe(Rating.VERY_GOOD, 0.4, 2.1, "맑음");

        assertThat(comment).doesNotContain("유의").doesNotContain("권하지 않습니다");
    }

    @Test
    @DisplayName("잔잔한 날에는 KHOA 가 VERY_GOOD 이어도 경고하지 않는다 — 오경보 방지")
    void doesNotWarnOnCalmDaysUnderTopRating() {
        // 돌산 갯바위 실측: 파고 0.3m · 풍속 4.3㎧ 인데 KHOA 는 VERY_GOOD.
        // 자체 기준으로는 GOOD 이라 '한 칸 어긋남'이 생기지만 이건 잔잔한 날이다.
        String comment = SpotComment.describe(Rating.VERY_GOOD, 0.3, 4.3, "흐림");

        assertThat(comment).doesNotContain("유의").doesNotContain("권하지 않습니다");
    }

    @Test
    @DisplayName("등급이 이미 낮으면 경고를 겹쳐 말하지 않는다")
    void doesNotPileOnWhenRatingIsAlreadyBad() {
        // 자체 기준으로도 BAD, KHOA 도 BAD 면 새로 알릴 게 없다.
        String comment = SpotComment.describe(Rating.BAD, 1.8, 9.0, "비");

        assertThat(comment).isEqualTo("어종 활성도가 낮아 조황을 기대하기 어렵습니다.");
    }

    @Test
    @DisplayName("강수는 문구에도 드러난다 — 등급 판정과 같은 기준을 쓴다")
    void mentionsPrecipitation() {
        // '소나기'에는 '비'도 '눈'도 안 들어간다. RatingRule 과 같은 판정을 써야
        // "등급은 내려갔는데 문구는 비 얘기가 없는" 어긋남이 안 생긴다.
        String comment = SpotComment.describe(Rating.GOOD, 0.7, 5.6, "소나기");

        assertThat(comment).contains("소나기").contains("유의");
    }

    @Test
    @DisplayName("파고·풍속이 없으면 등급만 보고 문구를 고른다")
    void fallsBackToRatingOnlyWhenNumbersMissing() {
        assertThat(SpotComment.describe(Rating.GOOD, null, 3.0, "맑음")).isNotBlank();
        assertThat(SpotComment.describe(Rating.GOOD, 0.5, null, "맑음")).isNotBlank();
    }

    @Test
    @DisplayName("컬럼이 VARCHAR(200) 이라 길이를 넘지 않는다")
    void fitsInTheColumn() {
        for (Rating rating : Rating.values()) {
            assertThat(SpotComment.describe(rating, 2.5, 12.0, "소나기")).hasSizeLessThanOrEqualTo(200);
            assertThat(SpotComment.describe(rating, 0.1, 0.5, "맑음")).hasSizeLessThanOrEqualTo(200);
        }
    }
}
