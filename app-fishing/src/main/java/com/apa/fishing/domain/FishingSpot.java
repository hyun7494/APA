package com.apa.fishing.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 출조 포인트. 지수 화면 카드와 상세 화면이 모두 이 한 행을 쓴다.
 *
 * <p>DECIMAL 컬럼은 {@link BigDecimal} 로 받는다 — double 로 매핑하면 ddl-auto: validate 가
 * numeric ↔ float8 불일치로 부팅을 막는다. 프론트로 나갈 때 DTO에서 double 로 바꾼다.
 *
 * <p>좌표·격자·관측소 코드는 시드에서 전부 NULL 이고 Step 6(공공 API 배치)에서 채운다.
 */
@Entity
@Table(name = "fishing_spots")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class FishingSpot {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "region_group_id", nullable = false)
    private FishingRegion region;

    private BigDecimal latitude;
    private BigDecimal longitude;

    @Column(name = "grid_nx")
    private Integer gridNx;

    @Column(name = "grid_ny")
    private Integer gridNy;

    @Column(name = "khoa_obs_code")
    private String khoaObsCode;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private Rating rating;

    @Column(name = "water_temp")
    private BigDecimal waterTemp;

    @Column(name = "wave_height")
    private BigDecimal waveHeight;

    @Column(name = "wind_speed")
    private BigDecimal windSpeed;

    private String weather;

    @Column(name = "tide_info")
    private String tideInfo;

    @Column(name = "sunrise_sunset")
    private String sunriseSunset;

    private String comment;

    /** 06/09/12/15/18/21시 조황 예상 %. 길이 6 고정 — 어긋나면 상세 그래프 x축과 안 맞는다. */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "hourly_forecast")
    private List<Integer> hourlyForecast;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "recommended_fish")
    private List<String> recommendedFish;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;
}
