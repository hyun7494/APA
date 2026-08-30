package com.apa.fishing.batch;

import com.apa.fishing.batch.khoa.KhoaFishingIndex;
import com.apa.fishing.batch.kma.KmaForecast;
import com.apa.fishing.domain.Rating;

import java.util.List;

/**
 * 두 기관 응답을 포인트 한 행으로 합친 결과. <b>순수 함수라 키 없이 단위 테스트로 검증된다.</b>
 *
 * <p>역할 분담 (2026-08-12 실측 후 정해진 것):
 * <ul>
 *   <li><b>KHOA</b> — 등급·추천 어종·수온·파고·풍속·물때. 해상 관측 기반이라 이쪽이 낫다
 *   <li><b>KMA</b> — 날씨 표기(맑음/흐림/비) 하나. 파고·풍속은 KHOA 가 없을 때만 쓴다
 *   <li><b>코멘트</b> — 파고·풍속이 등급보다 험하면 {@link SpotComment} 가 경고 문구를 만든다.
 *       <b>등급은 건드리지 않는다</b> — 어황('무느냐')과 안전('나가도 되느냐')은 다른 얘기라
 *       한 배지에 욱여넣으면 둘 다 못 읽게 된다
 * </ul>
 *
 * <p><b>null 은 "값 없음"이고 0 이 아니다.</b> 여기서 0.0 으로 채우면 결측이 "잔잔한 날"로
 * 위장되고, 안전 관련 수치라 그러면 안 된다. 엔티티 쪽에서도 null 은 덮어쓰지 않는다.
 */
public record SpotIndexUpdate(
        Rating rating,
        List<String> recommendedFish,
        Double waterTemp,
        Double waveHeight,
        Double windSpeed,
        String weather,
        String tideInfo,
        String comment,
        List<Integer> hourlyForecast,
        String sunriseSunset) {

    /**
     * 받아온 것들로 갱신 내용을 만든다.
     *
     * <p>KHOA 가 있으면 항목 대부분이 그쪽 값이다(등급만은 자체 규칙과 대조해 나쁜 쪽을 쓴다).
     * 없으면(= {@code khoa_place_name} 이 NULL 이거나 호출
     * 실패) 기상청 파고·풍속으로 {@link RatingRule} 을 돌리는 <b>폴백</b>이다. 영종도 선착장이
     * 상시 이 경로를 탄다 — 가장 가까운 KHOA 해역이 19.7km 밖 먼바다라 붙이지 않았다.
     *
     * @return 쓸 값이 하나도 없으면 {@code null}. 호출부는 그 포인트를 건너뛴다
     */
    public static SpotIndexUpdate combine(KhoaFishingIndex khoa, KmaForecast kma) {
        String weather = kma == null ? null : kma.weather();

        if (khoa != null) {
            Double waveHeight = firstNonNull(khoa.waveHeight(), waveHeightOf(kma));
            Double windSpeed = firstNonNull(khoa.windSpeed(), windSpeedOf(kma));

            return new SpotIndexUpdate(
                    khoa.rating(),
                    khoa.recommendedFish(),
                    khoa.waterTemp(),
                    waveHeight,
                    windSpeed,
                    weather,
                    khoa.tideInfo(),
                    SpotComment.describe(khoa.rating(), waveHeight, windSpeed, weather),
                    hourlyOf(kma),
                    null);          // 좌표로 계산한다 — 아래 withSunriseSunset
        }

        // 폴백. RatingRule 은 원시 double 을 받으므로 둘 다 있어야 돌릴 수 있다.
        // 내륙 격자에는 WAV 카테고리가 아예 없어 waveHeight 가 null 로 온다 — 그때는 등급을
        // 만들어내지 않고 포기한다. 없는 값을 0 으로 메우면 "파고 0m 인 아주 좋은 날"이 된다.
        Double waveHeight = waveHeightOf(kma);
        Double windSpeed = windSpeedOf(kma);
        if (waveHeight == null || windSpeed == null) {
            return null;
        }

        Rating rating = RatingRule.evaluate(waveHeight, windSpeed, weather);
        return new SpotIndexUpdate(
                rating,
                null,           // 어종 정보는 기상청에 없다. 기존 값을 남긴다
                null,           // 수온도 마찬가지
                waveHeight,
                windSpeed,
                weather,
                null,           // 물때도 마찬가지
                SpotComment.describe(rating, waveHeight, windSpeed, weather),
                hourlyOf(kma),
                null);              // 좌표로 계산한다 — 아래 withSunriseSunset
    }

    /**
     * 일출·일몰을 얹는다. <b>두 기관 어느 쪽에서도 오지 않는 값</b>이라 {@link #combine} 이
     * 만들 수 없다 — 좌표와 날짜만 있으면 {@link SolarTime} 이 계산해 준다.
     *
     * <p>따로 두는 이유가 하나 더 있다: API 가 전부 실패해도 이 값은 나온다. 그렇다고
     * 지수 없이 일출만 쓰지는 않는다 — {@code combine} 이 null 이면 그 포인트는 통째로 건너뛴다.
     */
    public SpotIndexUpdate withSunriseSunset(String sunriseSunset) {
        return new SpotIndexUpdate(rating, recommendedFish, waterTemp, waveHeight, windSpeed,
                weather, tideInfo, comment, hourlyForecast, sunriseSunset);
    }

    /**
     * 시간대별 그래프는 <b>언제나 기상청 쪽</b>이다. KHOA 바다낚시지수에는 시간축이 없다
     * (오전/오후 둘로만 나뉘고 그마저 앞 사흘뿐이다). KHOA 가 붙는 포인트에서도 이 값만은
     * 기상청에서 온다.
     */
    private static List<Integer> hourlyOf(KmaForecast kma) {
        return kma == null ? null : kma.hourly();
    }

    private static Double waveHeightOf(KmaForecast kma) {
        return kma == null ? null : kma.waveHeight();
    }

    private static Double windSpeedOf(KmaForecast kma) {
        return kma == null ? null : kma.windSpeed();
    }

    private static Double firstNonNull(Double preferred, Double fallback) {
        return preferred != null ? preferred : fallback;
    }
}
