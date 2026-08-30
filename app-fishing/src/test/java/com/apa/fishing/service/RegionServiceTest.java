package com.apa.fishing.service;

import com.apa.fishing.domain.Rating;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.Arrays;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 권역 미리보기 배지. 스프링 없이 도는 부분만 본다 — 평균 내는 규칙이 전부다.
 */
class RegionServiceTest {

    private static List<BigDecimal> temps(String... values) {
        return Arrays.stream(values)
                .map(v -> v == null ? null : new BigDecimal(v))
                .toList();
    }

    @Test
    @DisplayName("★ 한 포인트의 이상값이 권역을 통째로 끌고 가지 않는다")
    void oneOutlierDoesNotDecideTheRegion() {
        // 서해에서 실제로 있었던 일: 시드값이 굳은 영종도(16.2℃)가 id 가 가장 작아
        // 8월 말 서해 카드가 16.2℃ 였다. 나머지 열한 곳은 25~28℃ 다.
        Double average = RegionService.averageWaterTemp(
                temps("16.2", "28.8", "28.8", "27.4", "26.5", "27.0",
                        "26.7", "28.3", "27.1", "26.2", "27.1", "28.2"));

        assertThat(average).isBetween(26.0, 28.0);
    }

    @Test
    @DisplayName("수온이 없는 포인트는 0 으로 세지 않고 뺀다 — 0 으로 치면 평균이 끌려 내려간다")
    void skipsMissingTemps() {
        assertThat(RegionService.averageWaterTemp(temps("26.0", null, "28.0")))
                .isEqualTo(27.0);
    }

    @Test
    @DisplayName("잴 수 있는 포인트가 하나도 없으면 배지를 비운다")
    void noTempsMeansNoBadge() {
        assertThat(RegionService.averageWaterTemp(temps(null, null))).isNull();
        assertThat(RegionService.averageWaterTemp(List.of())).isNull();
        assertThat(RegionService.averageRating(List.of())).isNull();
    }

    @Test
    @DisplayName("소수점 1자리로 맞춘다 — 화면이 그대로 찍는다")
    void roundsToOneDecimal() {
        assertThat(RegionService.averageWaterTemp(temps("26.0", "27.0", "28.1")))
                .isEqualTo(27.0);
        assertThat(RegionService.averageWaterTemp(temps("26.0", "27.1")))
                .isEqualTo(26.6);
    }

    @Test
    @DisplayName("★ 등급도 평균이다 — 한 곳이 나쁘다고 권역 전체가 나쁨이 되지 않는다")
    void ratingIsAveragedNotWorst() {
        List<Rating> ratings = List.of(
                Rating.GOOD, Rating.GOOD, Rating.GOOD, Rating.GOOD, Rating.BAD);

        assertThat(RegionService.averageRating(ratings)).isEqualTo(Rating.GOOD);
    }

    @Test
    @DisplayName("정말로 다 나쁘면 나쁨이 나온다")
    void allBadStaysBad() {
        assertThat(RegionService.averageRating(List.of(Rating.BAD, Rating.BAD)))
                .isEqualTo(Rating.BAD);
        assertThat(RegionService.averageRating(List.of(Rating.VERY_GOOD, Rating.VERY_GOOD)))
                .isEqualTo(Rating.VERY_GOOD);
    }
}
