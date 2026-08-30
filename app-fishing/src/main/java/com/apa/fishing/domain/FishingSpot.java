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
import java.math.RoundingMode;
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

    /**
     * KHOA 바다낚시지수의 {@code seafsPstnNm}. <b>관측소 코드가 아니라 해역명이다.</b>
     *
     * <p>NULL 이면 그 포인트는 KHOA 로 못 채운다는 뜻이고, 배치가 기상청 + {@code RatingRule}
     * 폴백으로 등급을 낸다 (영종도 선착장이 그렇다). 자세한 사정은 V6 마이그레이션 주석 참고.
     */
    @Column(name = "khoa_place_name", length = 40)
    private String khoaPlaceName;

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

    /**
     * 공공 API 배치 결과를 반영한다.
     *
     * <p><b>null 인 인자는 덮어쓰지 않고 기존 값을 남긴다.</b> 두 API 가 항목을 제각각 주기
     * 때문이다 — 예를 들어 KHOA 가 안 붙는 영종도는 수온·물때가 늘 null 로 온다. 이걸 그대로
     * 써서 컬럼을 비우면 {@code SpotResponse.toDouble(null)} 이 <b>0.0 을 내보내</b>
     * 화면에 "0.0℃"가 뜬다. 값이 없는 것과 0 은 완전히 다른 뜻이라 기존 값을 남기는 쪽을 택했다.
     * (그 대가로 영종도의 수온·물때는 시드 값에 머문다 — 알고 있는 한계다.)
     *
     * <p>DECIMAL 스케일 변환도 여기서 한다. 컬럼 정의 바로 옆이라야 어긋나지 않는다.
     */
    public void applyIndex(Rating rating,
                           List<String> recommendedFish,
                           Double waterTemp,
                           Double waveHeight,
                           Double windSpeed,
                           String weather,
                           String tideInfo,
                           String comment,
                           List<Integer> hourlyForecast,
                           String sunriseSunset,
                           LocalDateTime updatedAt) {
        if (rating != null) {
            this.rating = rating;
        }
        // ⚠️ 빈 목록도 덮어쓰지 않는다. 어종을 '-' 하나로만 주는 해역이 있는데
        //    (인천항 서측·안흥항 같은 먼바다 지점 17곳) 파서가 그걸 걸러내면 빈 목록이 온다.
        //    빈 목록은 "추천할 어종이 없다" 가 아니라 **그 해역이 어종을 안 준다**는 뜻이라
        //    기존 값을 지울 근거가 못 된다. null 을 안 덮어쓰는 것과 같은 이유다.
        if (recommendedFish != null && !recommendedFish.isEmpty()) {
            this.recommendedFish = recommendedFish;
        }
        if (waterTemp != null) {
            this.waterTemp = scaled(waterTemp);      // DECIMAL(4,1)
        }
        if (waveHeight != null) {
            this.waveHeight = scaled(waveHeight);    // DECIMAL(3,1)
        }
        if (windSpeed != null) {
            this.windSpeed = scaled(windSpeed);      // DECIMAL(4,1)
        }
        if (weather != null) {
            this.weather = weather;
        }
        if (tideInfo != null) {
            this.tideInfo = tideInfo;
        }
        if (comment != null && !comment.isBlank()) {
            this.comment = comment;
        }
        if (hourlyForecast != null) {
            this.hourlyForecast = hourlyForecast;
        }
        if (sunriseSunset != null) {
            this.sunriseSunset = sunriseSunset;
        }
        this.updatedAt = updatedAt;
    }

    private static BigDecimal scaled(double value) {
        return BigDecimal.valueOf(value).setScale(1, RoundingMode.HALF_UP);
    }
}
