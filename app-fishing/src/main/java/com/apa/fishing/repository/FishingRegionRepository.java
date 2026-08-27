package com.apa.fishing.repository;

import com.apa.fishing.domain.FishingRegion;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface FishingRegionRepository extends JpaRepository<FishingRegion, Long> {

    List<FishingRegion> findAllByOrderByIdAsc();

    /**
     * 지역명 · 시도명 · <b>그 지역의 포인트 이름</b> 아무 쪽이나 걸리면 된다.
     *
     * <p>검색창 안내가 "지역 또는 포인트 검색" 인데 포인트 이름은 안 걸렸다 —
     * {@code 학리} 를 치면 결과가 없었다. 사람은 자기가 아는 포인트 이름으로 찾는다.
     *
     * <p>{@code distinct} 가 필요하다. 한 지역의 포인트 둘이 같이 걸리면
     * ({@code 기장 학리} · {@code 기장 대변항 방파제} 에 "기장") 지역이 두 번 나온다.
     */
    @Query("select distinct r from FishingRegion r "
            + "where lower(r.name) like lower(concat('%', :q, '%')) "
            + "   or lower(r.area) like lower(concat('%', :q, '%')) "
            + "   or exists ("
            + "       select 1 from FishingSpot s "
            + "       where s.region = r "
            + "         and lower(s.name) like lower(concat('%', :q, '%'))"
            + "   ) "
            + "order by r.id")
    List<FishingRegion> search(@Param("q") String q);
}
