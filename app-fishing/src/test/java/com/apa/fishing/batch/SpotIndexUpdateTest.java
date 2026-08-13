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
    @DisplayName("KHOA 가 있으면 등급·어종·수온·물때는 KHOA 것을 쓴다")
    void prefersKhoa() {
        SpotIndexUpdate update = SpotIndexUpdate.combine(
                khoa(Rating.GOOD, 0.7, 4.9),
                new KmaForecast("맑음", 9.9, 3.3));

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
                new KmaForecast("흐림", 3.0, 0.5));

        assertThat(update.weather()).isEqualTo("흐림");
    }

    @Test
    @DisplayName("KHOA 의 파고·풍속이 비면 기상청 값으로 메운다")
    void fallsBackToKmaForMissingNumbers() {
        SpotIndexUpdate update = SpotIndexUpdate.combine(
                khoa(Rating.NORMAL, null, null),
                new KmaForecast("맑음", 5.5, 1.2));

        assertThat(update.waveHeight()).isEqualTo(1.2);
        assertThat(update.windSpeed()).isEqualTo(5.5);
        assertThat(update.rating()).isEqualTo(Rating.NORMAL);   // 등급은 여전히 KHOA 것
    }

    @Test
    @DisplayName("KHOA 가 없으면 기상청 + RatingRule 폴백으로 등급을 낸다 (영종도 경로)")
    void fallsBackToRatingRule() {
        SpotIndexUpdate update = SpotIndexUpdate.combine(null, new KmaForecast("맑음", 5.2, 0.9));

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
        SpotIndexUpdate update = SpotIndexUpdate.combine(null, new KmaForecast("소나기", 2.1, 0.4));

        // 0.4m / 2.1㎧ 는 VERY_GOOD 인데 강수로 한 단계 내려간다.
        // '소나기'에는 '비'도 '눈'도 안 들어간다 — RatingRule 이 따로 잡는 이유다
        assertThat(update.rating()).isEqualTo(Rating.GOOD);
    }

    @Test
    @DisplayName("폴백인데 파고가 없으면 등급을 만들지 않는다 — 결측을 0으로 메우면 안 된다")
    void refusesFallbackWithoutWaveHeight() {
        // 내륙 격자에는 WAV 카테고리 자체가 응답에 없다. 0.0 으로 채우면
        // 격자 오계산이 "파고 0m 인 아주 좋은 날"로 위장된다.
        assertThat(SpotIndexUpdate.combine(null, new KmaForecast("맑음", 3.0, null))).isNull();
    }

    @Test
    @DisplayName("둘 다 실패하면 null — 호출부가 그 포인트를 건너뛴다")
    void yieldsNothingWhenBothFail() {
        assertThat(SpotIndexUpdate.combine(null, null)).isNull();
    }
}
