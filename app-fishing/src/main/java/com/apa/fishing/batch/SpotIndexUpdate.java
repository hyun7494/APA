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
        String tideInfo) {

    /**
     * 받아온 것들로 갱신 내용을 만든다.
     *
     * <p>KHOA 가 있으면 그쪽이 기준이다. 없으면(= {@code khoa_place_name} 이 NULL 이거나 호출
     * 실패) 기상청 파고·풍속으로 {@link RatingRule} 을 돌리는 <b>폴백</b>이다. 영종도 선착장이
     * 상시 이 경로를 탄다 — 가장 가까운 KHOA 해역이 19.7km 밖 먼바다라 붙이지 않았다.
     *
     * @return 쓸 값이 하나도 없으면 {@code null}. 호출부는 그 포인트를 건너뛴다
     */
    public static SpotIndexUpdate combine(KhoaFishingIndex khoa, KmaForecast kma) {
        String weather = kma == null ? null : kma.weather();

        if (khoa != null) {
            return new SpotIndexUpdate(
                    khoa.rating(),
                    khoa.recommendedFish(),
                    khoa.waterTemp(),
                    firstNonNull(khoa.waveHeight(), waveHeightOf(kma)),
                    firstNonNull(khoa.windSpeed(), windSpeedOf(kma)),
                    weather,
                    khoa.tideInfo());
        }

        // 폴백. RatingRule 은 원시 double 을 받으므로 둘 다 있어야 돌릴 수 있다.
        // 내륙 격자에는 WAV 카테고리가 아예 없어 waveHeight 가 null 로 온다 — 그때는 등급을
        // 만들어내지 않고 포기한다. 없는 값을 0 으로 메우면 "파고 0m 인 아주 좋은 날"이 된다.
        Double waveHeight = waveHeightOf(kma);
        Double windSpeed = windSpeedOf(kma);
        if (waveHeight == null || windSpeed == null) {
            return null;
        }

        return new SpotIndexUpdate(
                RatingRule.evaluate(waveHeight, windSpeed, weather),
                null,           // 어종 정보는 기상청에 없다. 기존 값을 남긴다
                null,           // 수온도 마찬가지
                waveHeight,
                windSpeed,
                weather,
                null);          // 물때도 마찬가지
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
