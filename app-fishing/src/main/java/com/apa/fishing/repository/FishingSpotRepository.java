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

    /**
     * 이름으로 포인트를 찾는다. 검색 화면이 <b>포인트를 바로 고를 수 있게</b> 하려고 쓴다.
     *
     * <p>지역 검색({@code RegionRepository.search})만 있을 때는 `울릉` 을 쳐도 결과가
     * `동해` 라, 사용자가 권역을 누른 뒤 14곳 중에서 울릉도를 다시 찾아야 했다.
     */
    @Query("select s from FishingSpot s join fetch s.region "
            + "where lower(s.name) like lower(concat('%', :q, '%')) order by s.id")
    List<FishingSpot> searchByName(@Param("q") String q);
}
