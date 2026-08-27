package com.apa.fishing.repository;

import com.apa.fishing.domain.SpotDailyIndex;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;

public interface SpotDailyIndexRepository
        extends JpaRepository<SpotDailyIndex, SpotDailyIndex.Key> {

    /**
     * 있으면 덮고 없으면 넣는다.
     *
     * <p>예보 창이 매일 겹쳐 들어오므로(어제 받은 D+1 이 오늘의 D+0 이다) 덮어쓰기가
     * 기본 동작이라야 한다. "조회 후 저장" 으로 나누면 배치가 겹쳐 돌 때 PK 에 걸리고,
     * 그 예외는 잡아도 트랜잭션이 이미 롤백 전용이라 소용이 없다
     * ({@code FishingPostLikeRepository.insertIfAbsent} 와 같은 이유).
     */
    @Modifying
    @Query(value = """
            INSERT INTO fishing_spot_daily_index
                (spot_id, forecast_date, rating, wave_height, wind_speed, water_temp, updated_at)
            VALUES (:spotId, :date, :rating, :waveHeight, :windSpeed, :waterTemp, :updatedAt)
            ON CONFLICT (spot_id, forecast_date) DO UPDATE SET
                rating      = EXCLUDED.rating,
                wave_height = EXCLUDED.wave_height,
                wind_speed  = EXCLUDED.wind_speed,
                water_temp  = EXCLUDED.water_temp,
                updated_at  = EXCLUDED.updated_at
            """, nativeQuery = true)
    void upsert(@Param("spotId") Long spotId,
                @Param("date") LocalDate date,
                @Param("rating") String rating,
                @Param("waveHeight") Double waveHeight,
                @Param("windSpeed") Double windSpeed,
                @Param("waterTemp") Double waterTemp,
                @Param("updatedAt") java.time.LocalDateTime updatedAt);

    /** 한 포인트의 오늘 이후 예보. 지난 날짜는 화면에 쓸 일이 없다. */
    List<SpotDailyIndex> findBySpotIdAndForecastDateGreaterThanEqualOrderByForecastDate(
            Long spotId, LocalDate from);

    /** 목록 화면용 — 여러 포인트를 <b>질의 한 번</b>에 읽는다. */
    List<SpotDailyIndex> findBySpotIdInAndForecastDateGreaterThanEqualOrderByForecastDate(
            Collection<Long> spotIds, LocalDate from);

    /**
     * 지나간 예보를 치운다. 오늘 이후만 화면에 쓰므로 남겨 둘 이유가 없고,
     * 놔두면 포인트마다 하루 한 행씩 영원히 쌓인다.
     */
    void deleteByForecastDateLessThan(LocalDate from);
}
