package com.apa.fishing.dto;

import com.apa.fishing.domain.FishingSpot;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 계약서 3-3 / 3-4. 목록과 상세가 같은 형태다 — 목록에서도 전 필드를 내려주면
 * 상세 진입이 네트워크 없이 즉시 렌더된다.
 */
public record SpotResponse(
        Long id,
        String name,
        Long regionGroupId,
        String regionName,
        String rating,
        double waterTemp,
        double waveHeight,
        double windSpeed,
        String weather,
        String tideInfo,
        String sunriseSunset,
        String comment,
        List<Integer> hourlyForecast,
        List<String> recommendedFish,
        List<DailyIndexResponse> weeklyIndex,
        Double distanceKm,
        LocalDateTime updatedAt
) {

    /** 상세 그래프 x축이 06/09/12/15/18/21시 6칸 고정이라 응답도 6칸을 맞춰 보낸다. */
    private static final int FORECAST_SLOTS = 6;

    public static SpotResponse from(FishingSpot spot) {
        return from(spot, List.of());
    }

    /** 내 위치에서 몇 km 인지 붙여서 준다 (`GET /fishing/spots?lat=&lon=`). */
    public SpotResponse withDistance(double km) {
        return new SpotResponse(id, name, regionGroupId, regionName, rating, waterTemp,
                waveHeight, windSpeed, weather, tideInfo, sunriseSunset, comment,
                hourlyForecast, recommendedFish, weeklyIndex, km, updatedAt);
    }

    /**
     * @param week 주간 예보 (V13). 없으면 빈 목록이다 — KHOA 해역이 안 붙은 포인트(영종도)와
     *             예보가 아직 안 들어온 포인트가 그렇다. 앱은 그때 스트립을 통째로 감춘다
     */
    public static SpotResponse from(FishingSpot spot, List<DailyIndexResponse> week) {
        return new SpotResponse(
                spot.getId(),
                spot.getName(),
                spot.getRegion().getId(),
                spot.getRegion().getName(),
                spot.getRating().name(),
                toDouble(spot.getWaterTemp()),
                toDouble(spot.getWaveHeight()),
                toDouble(spot.getWindSpeed()),
                orDash(spot.getWeather()),
                orDash(spot.getTideInfo()),
                orDash(spot.getSunriseSunset()),
                spot.getComment() == null ? "" : spot.getComment(),
                padForecast(spot.getHourlyForecast()),
                spot.getRecommendedFish() == null ? List.of() : spot.getRecommendedFish(),
                week,
                null,                 // 거리는 위치 검색일 때만 채운다
                spot.getUpdatedAt()
        );
    }

    private static double toDouble(BigDecimal value) {
        return value == null ? 0d : value.doubleValue();
    }

    private static String orDash(String value) {
        return value == null || value.isBlank() ? "-" : value;
    }

    /**
     * 여섯 칸이 아니면 <b>빈 목록</b>이다. 앱은 그때 그래프 카드를 통째로 감춘다.
     *
     * <p>⚠️ 여기서 0 으로 메우면 안 된다. 예전엔 null 을 {@code [0,0,0,0,0,0]} 으로 채웠는데,
     * 그러면 <b>예보가 없는 포인트가 "온종일 조황 0, 06시 최적"</b> 이라고 단언하는 화면이 된다.
     * 배치가 {@code hourly_forecast} 를 안 채우던 45곳이 전부 그 상태였다.
     * 없는 값과 0 은 다른 뜻이다 — {@code SpotIndexUpdate} 가 지키는 규칙과 같다.
     */
    private static List<Integer> padForecast(List<Integer> forecast) {
        if (forecast == null || forecast.size() != FORECAST_SLOTS) {
            return List.of();
        }
        return forecast;
    }
}
