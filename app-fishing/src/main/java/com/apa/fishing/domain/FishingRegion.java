package com.apa.fishing.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/** 지역 그룹. 프론트 RegionGroup 에 대응한다 ("부산 기장" / "부산광역시"). */
@Entity
@Table(name = "fishing_regions")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class FishingRegion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String area;
}
