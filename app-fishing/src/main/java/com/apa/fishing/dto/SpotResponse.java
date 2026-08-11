package com.apa.fishing.dto;

import com.apa.fishing.domain.FishingSpot;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
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
        LocalDateTime updatedAt
) {

    /** 상세 그래프 x축이 06/09/12/15/18/21시 6칸 고정이라 응답도 6칸을 맞춰 보낸다. */
    private static final int FORECAST_SLOTS = 6;

    public static SpotResponse from(FishingSpot spot) {
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
                spot.getUpdatedAt()
        );
    }

    private static double toDouble(BigDecimal value) {
        return value == null ? 0d : value.doubleValue();
    }

    private static String orDash(String value) {
        return value == null || value.isBlank() ? "-" : value;
    }

    private static List<Integer> padForecast(List<Integer> forecast) {
        if (forecast == null) {
            return List.of(0, 0, 0, 0, 0, 0);
        }
        if (forecast.size() == FORECAST_SLOTS) {
            return forecast;
        }
        List<Integer> padded = new ArrayList<>(forecast.subList(0, Math.min(forecast.size(), FORECAST_SLOTS)));
        while (padded.size() < FORECAST_SLOTS) {
            padded.add(0);
        }
        return padded;
    }
}
