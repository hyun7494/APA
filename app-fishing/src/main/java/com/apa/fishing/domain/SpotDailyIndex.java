package com.apa.fishing.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Objects;

/**
 * 포인트 한 곳의 하루치 예보 (V13).
 *
 * <p><b>이 엔티티로 저장하지 않는다.</b> 넣는 일은
 * {@link com.apa.fishing.repository.SpotDailyIndexRepository#upsert} 가 네이티브 upsert 로 한다 —
 * 예보 창이 매일 겹쳐서 들어오므로 "있으면 덮고 없으면 넣기" 가 기본 동작이라야 한다.
 * 여기는 읽는 자리다.
 */
@Entity
@Table(name = "fishing_spot_daily_index")
@IdClass(SpotDailyIndex.Key.class)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SpotDailyIndex {

    @Id
    @Column(name = "spot_id", nullable = false)
    private Long spotId;

    @Id
    @Column(name = "forecast_date", nullable = false)
    private LocalDate forecastDate;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Rating rating;

    @Column(name = "wave_height")
    private BigDecimal waveHeight;

    @Column(name = "wind_speed")
    private BigDecimal windSpeed;

    @Column(name = "water_temp")
    private BigDecimal waterTemp;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    public record Key(Long spotId, LocalDate forecastDate) implements Serializable {

        public Key() {
            this(null, null);
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Key other)) return false;
            return Objects.equals(spotId, other.spotId)
                    && Objects.equals(forecastDate, other.forecastDate);
        }

        @Override
        public int hashCode() {
            return Objects.hash(spotId, forecastDate);
        }
    }
}
