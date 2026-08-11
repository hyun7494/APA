package com.apa.fishing.repository;

import com.apa.fishing.domain.FishingRegion;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface FishingRegionRepository extends JpaRepository<FishingRegion, Long> {

    List<FishingRegion> findAllByOrderByIdAsc();

    /** 지역명·시도명 아무 쪽이나 걸리면 된다. 프론트 검색창은 "기장", "부산" 둘 다 친다. */
    List<FishingRegion> findByNameContainingIgnoreCaseOrAreaContainingIgnoreCaseOrderByIdAsc(
            String name, String area);
}
