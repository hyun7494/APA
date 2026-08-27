package com.apa.fishing.service;

import com.apa.fishing.domain.FishingRegion;
import com.apa.fishing.domain.FishingSpot;
import com.apa.fishing.dto.RegionGroupResponse;
import com.apa.fishing.repository.FishingRegionRepository;
import com.apa.fishing.repository.FishingSpotRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RegionService {

    private final FishingRegionRepository regionRepository;
    private final FishingSpotRepository spotRepository;

    public List<RegionGroupResponse> findAll() {
        return toResponses(regionRepository.findAllByOrderByIdAsc());
    }

    /** 검색어가 비면 전체를 준다 — 프론트가 검색창이 비었을 때도 이 엔드포인트를 호출한다. */
    public List<RegionGroupResponse> search(String query) {
        if (query == null || query.isBlank()) {
            return findAll();
        }
        return toResponses(regionRepository.search(query.trim()));
    }

    /**
     * 즐겨찾는 지역 칩 (마이페이지). 목록이 비면 질의하지 않는다 —
     * 즐겨찾기가 없는 사용자가 대부분인데 그때마다 포인트를 전부 읽을 이유가 없다.
     */
    public List<RegionGroupResponse> findByIds(Collection<Long> ids) {
        if (ids == null || ids.isEmpty()) return List.of();
        return toResponses(regionRepository.findAllById(ids));
    }

    /**
     * 미리보기 등급·수온은 그룹의 첫 포인트 값이다. 지역 수가 5개뿐이라 포인트를 한 번에 읽어
     * 메모리에서 묶는다 — 지역마다 조회하면 N+1 이 된다.
     */
    private List<RegionGroupResponse> toResponses(List<FishingRegion> regions) {
        Map<Long, List<FishingSpot>> spotsByRegion = spotRepository.findAllWithRegion().stream()
                .collect(Collectors.groupingBy(spot -> spot.getRegion().getId()));

        return regions.stream()
                .map(region -> {
                    List<FishingSpot> spots = spotsByRegion.getOrDefault(region.getId(), List.of());
                    FishingSpot first = spots.isEmpty() ? null : spots.get(0);
                    return RegionGroupResponse.of(region, first, spots.size());
                })
                .toList();
    }
}
