package com.apa.fishing.batch;

import com.apa.fishing.batch.khoa.KhoaFishingIndex;
import com.apa.fishing.batch.kma.KmaForecast;
import com.apa.fishing.domain.Rating;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 두 기관 응답을 합치는 규칙. 판단이 들어간 곳이라 바꾸려면 여기 테스트부터 볼 것.
 */
class SpotIndexUpdateTest {

    private static KhoaFishingIndex khoa(Rating rating, Double wave, Double wind) {
        return new KhoaFishingIndex("부산동부", rating, List.of("감성돔"), 24.5, wave, wind, "중조기");
    }

    @Test
    @DisplayName("기상이 험해도 등급은 KHOA 것을 유지하고 경고는 코멘트로 낸다 (구룡포 사례)")
    void keepsKhoaRatingAndWarnsInComment() {
        // 2026-08-14 구룡포 실측: 풍속 8.3㎧ 인데 KHOA 는 '보통'이었다.
        // 어황('무느냐')과 안전('나가도 되느냐')은 다른 얘기라 등급을 덮지 않는다.
        SpotIndexUpdate update = SpotIndexUpdate.combine(
                khoa(Rating.NORMAL, 0.8, 8.3),
                new KmaForecast("흐림", 8.3, 0.8, null));

        assertThat(update.rating()).isEqualTo(Rating.NORMAL);        // 어황 그대로
        assertThat(update.recommendedFish()).containsExactly("감성돔");
        assertThat(update.comment())
                .contains("8.3")                                     // 수치를 박는다
                .contains("강풍")
                .contains("출조를 권하지 않습니다");
    }

    @Test
    @DisplayName("기상이 등급만큼 나쁘지 않으면 경고 없이 평범한 코멘트가 붙는다")
    void writesPlainCommentWhenConditionsAreCalm() {
        SpotIndexUpdate update = SpotIndexUpdate.combine(
                khoa(Rating.GOOD, 0.3, 2.0),
                new KmaForecast("맑음", 2.0, 0.3, null));

        assertThat(update.rating()).isEqualTo(Rating.GOOD);
        assertThat(update.comment()).doesNotContain("유의").doesNotContain("권하지");
    }

    @Test
    @DisplayName("파고·풍속이 없으면 대조할 수 없으니 KHOA 등급을 그대로 둔다")
    void keepsKhoaRatingWhenNumbersAreMissing() {
        SpotIndexUpdate update = SpotIndexUpdate.combine(khoa(Rating.GOOD, null, null), null);

        assertThat(update.rating()).isEqualTo(Rating.GOOD);
        assertThat(update.waveHeight()).isNull();
        assertThat(update.comment()).isNotBlank();
    }

    @Test
    @DisplayName("KHOA 가 있으면 어종·수온·물때는 KHOA 것을 쓴다")
    void prefersKhoa() {
        SpotIndexUpdate update = SpotIndexUpdate.combine(
                khoa(Rating.GOOD, 0.7, 4.9),
                new KmaForecast("맑음", 9.9, 3.3, null));

        assertThat(update.rating()).isEqualTo(Rating.GOOD);
        assertThat(update.recommendedFish()).containsExactly("감성돔");
        assertThat(update.waterTemp()).isEqualTo(24.5);
        assertThat(update.tideInfo()).isEqualTo("중조기");
        // 파고·풍속도 해상 관측 기반인 KHOA 쪽이 우선이다
        assertThat(update.waveHeight()).isEqualTo(0.7);
        assertThat(update.windSpeed()).isEqualTo(4.9);
    }

    @Test
    @DisplayName("날씨 표기는 KHOA 에 없다 — 기상청에서만 온다")
    void takesWeatherFromKma() {
        SpotIndexUpdate update = SpotIndexUpdate.combine(
                khoa(Rating.GOOD, 0.7, 4.9),
                new KmaForecast("흐림", 3.0, 0.5, null));

        assertThat(update.weather()).isEqualTo("흐림");
    }

    @Test
    @DisplayName("KHOA 의 파고·풍속이 비면 기상청 값으로 메운다")
    void fallsBackToKmaForMissingNumbers() {
        SpotIndexUpdate update = SpotIndexUpdate.combine(
                khoa(Rating.NORMAL, null, null),
                new KmaForecast("맑음", 5.5, 1.2, null));

        assertThat(update.waveHeight()).isEqualTo(1.2);
        assertThat(update.windSpeed()).isEqualTo(5.5);
        assertThat(update.rating()).isEqualTo(Rating.NORMAL);   // 등급은 여전히 KHOA 것
    }

    @Test
    @DisplayName("KHOA 가 없으면 기상청 + RatingRule 폴백으로 등급을 낸다 (영종도 경로)")
    void fallsBackToRatingRule() {
        SpotIndexUpdate update = SpotIndexUpdate.combine(null, new KmaForecast("맑음", 5.2, 0.9, null));

        assertThat(update.rating()).isEqualTo(Rating.NORMAL);   // 0.9m / 5.2㎧
        assertThat(update.waveHeight()).isEqualTo(0.9);
        assertThat(update.windSpeed()).isEqualTo(5.2);
        // 기상청에 없는 항목은 null 로 남겨 기존 값을 덮어쓰지 않게 한다
        assertThat(update.waterTemp()).isNull();
        assertThat(update.tideInfo()).isNull();
        assertThat(update.recommendedFish()).isNull();
    }

    @Test
    @DisplayName("폴백에서 날씨가 나쁘면 한 단계 낮춘다")
    void fallbackAppliesWeatherPenalty() {
        SpotIndexUpdate update = SpotIndexUpdate.combine(null, new KmaForecast("소나기", 2.1, 0.4, null));

        // 0.4m / 2.1㎧ 는 VERY_GOOD 인데 강수로 한 단계 내려간다.
        // '소나기'에는 '비'도 '눈'도 안 들어간다 — RatingRule 이 따로 잡는 이유다
        assertThat(update.rating()).isEqualTo(Rating.GOOD);
    }

    @Test
    @DisplayName("폴백인데 파고가 없으면 등급을 만들지 않는다 — 결측을 0으로 메우면 안 된다")
    void refusesFallbackWithoutWaveHeight() {
        // 내륙 격자에는 WAV 카테고리 자체가 응답에 없다. 0.0 으로 채우면
        // 격자 오계산이 "파고 0m 인 아주 좋은 날"로 위장된다.
        assertThat(SpotIndexUpdate.combine(null, new KmaForecast("맑음", 3.0, null, null))).isNull();
    }

    @Test
    @DisplayName("둘 다 실패하면 null — 호출부가 그 포인트를 건너뛴다")
    void yieldsNothingWhenBothFail() {
        assertThat(SpotIndexUpdate.combine(null, null)).isNull();
    }

    @Test
    @DisplayName("★ 일출·일몰은 API 가 아니라 좌표에서 온다 — 두 기관 어디에도 없는 값이다")
    void sunriseComesFromCoordinates() {
        SpotIndexUpdate update = SpotIndexUpdate
                .combine(null, new KmaForecast("맑음", 3.0, 0.5, null))
                .withSunriseSunset("05:52 / 18:52");

        assertThat(update.sunriseSunset()).isEqualTo("05:52 / 18:52");
        // 나머지는 그대로다
        assertThat(update.weather()).isEqualTo("맑음");
        assertThat(update.windSpeed()).isEqualTo(3.0);
    }
}
