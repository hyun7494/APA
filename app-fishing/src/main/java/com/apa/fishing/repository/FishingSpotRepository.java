package com.apa.fishing.repository;

import com.apa.fishing.domain.FishingSpot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface FishingSpotRepository extends JpaRepository<FishingSpot, Long> {

    /**
     * region 을 join fetch 한다 — open-in-view: false 라서 DTO 변환 시점에 지연 로딩을 시도하면
     * 세션이 이미 닫혀 있다 (regionName 이 빈 문자열로 나가는 원인).
     */
    @Query("select s from FishingSpot s join fetch s.region r where r.id = :regionGroupId order by s.id")
    List<FishingSpot> findByRegionId(@Param("regionGroupId") Long regionGroupId);

    @Query("select s from FishingSpot s join fetch s.region order by s.id")
    List<FishingSpot> findAllWithRegion();

    @Query("select s from FishingSpot s join fetch s.region where s.id = :id")
    Optional<FishingSpot> findWithRegionById(@Param("id") Long id);
}
