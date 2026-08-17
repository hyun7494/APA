package com.apa.fishing.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * 어종 마스터. 도감의 뼈대이며 <b>관리자만 수정하는 시드 데이터</b>다 — 사용자 등록으로 늘지 않는다.
 * (기획서 v2 3-2, 시드는 {@code V8__seed_species.sql})
 *
 * <p>DECIMAL 컬럼을 {@link BigDecimal} 로 받는 이유는 {@link FishingSpot} 과 같다 —
 * double 로 매핑하면 {@code ddl-auto: validate} 가 numeric ↔ float8 불일치로 부팅을 막는다.
 */
@Entity
@Table(name = "fishing_species")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Species {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** "감성돔" */
    @Column(nullable = false)
    private String name;

    /** "Acanthopagrus schlegelii". 없는 종이 많다 */
    @Column(name = "name_sci")
    private String nameSci;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Habitat habitat;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Rarity rarity;

    /**
     * 포획금지체장 cm. 「수산자원관리법 시행령」기준의 <b>참고값</b>이다 —
     * 앱은 위법 여부를 판정하지 않고 정보로만 노출한다 (기획서 7장).
     */
    @Column(name = "min_legal_size")
    private BigDecimal minLegalSize;

    /** 금어기 "12/01~01/31" */
    @Column(name = "closed_season")
    private String closedSeason;

    /** 제철 "9월 ~ 12월", "연중" */
    private String season;

    private String description;

    /**
     * 컬러 일러스트 경로. 에셋 미확보라 지금은 전부 NULL 이고,
     * 이때 프론트는 사용자 인증샷을 도감 칸 표지로 쓴다.
     */
    @Column(name = "illust_path")
    private String illustPath;

    @Column(name = "display_order", nullable = false)
    private int displayOrder;

    @Column(name = "is_active", nullable = false)
    private boolean active;
}
