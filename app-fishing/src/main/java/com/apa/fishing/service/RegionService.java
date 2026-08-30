package com.apa.fishing.service;

import com.apa.fishing.domain.FishingRegion;
import com.apa.fishing.domain.FishingSpot;
import com.apa.fishing.domain.Rating;
import com.apa.fishing.dto.RegionGroupResponse;
import com.apa.fishing.repository.FishingRegionRepository;
import com.apa.fishing.repository.FishingSpotRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Objects;
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
     * 미리보기 등급·수온은 <b>권역 전체의 평균</b>이다. 포인트를 한 번에 읽어 메모리에서
     * 묶는다 — 권역마다 조회하면 N+1 이 된다.
     *
     * <p>⚠️ 예전엔 <b>첫 포인트</b> 값을 그대로 썼다. 권역이 4개에 51곳이 된 뒤로는
     * 그게 "id 가 가장 작은 곳" 이라는 뜻밖에 안 된다. 실제로 서해의 첫 포인트가
     * 시드값이 굳은 영종도라서, 8월 말 서해 카드에 <b>16.2℃</b> 가 떠 있었다.
     * 한 곳이 이상하다고 권역 전체가 이상해 보이면 안 되므로 평균으로 바꿨다.
     */
    private List<RegionGroupResponse> toResponses(List<FishingRegion> regions) {
        Map<Long, List<FishingSpot>> spotsByRegion = spotRepository.findAllWithRegion().stream()
                .collect(Collectors.groupingBy(spot -> spot.getRegion().getId()));

        return regions.stream()
                .map(region -> {
                    List<FishingSpot> spots = spotsByRegion.getOrDefault(region.getId(), List.of());
                    return RegionGroupResponse.of(
                            region,
                            averageRating(spots.stream().map(FishingSpot::getRating).toList()),
                            averageWaterTemp(
                                    spots.stream().map(FishingSpot::getWaterTemp).toList()),
                            spots.size());
                })
                .toList();
    }

    /**
     * 권역 평균 수온. 값이 없는 포인트는 <b>빼고</b> 센다 — 0 으로 치면 평균이 끌려 내려간다.
     *
     * <p>패키지 공개 범위인 것은 테스트에서 직접 부르기 위해서다.
     *
     * @return 수온을 가진 포인트가 하나도 없으면 null. 프론트가 그때 배지를 숨긴다
     */
    static Double averageWaterTemp(List<BigDecimal> temps) {
        return temps.stream()
                .filter(Objects::nonNull)
                .mapToDouble(BigDecimal::doubleValue)
                .average()
                .stream().boxed().findFirst()
                .map(average -> BigDecimal.valueOf(average)
                        .setScale(1, RoundingMode.HALF_UP).doubleValue())
                .orElse(null);
    }

    /**
     * 권역 평균 등급. {@link Rating} 은 좋은 것부터 선언돼 있어 서수의 평균이 그대로 통한다.
     *
     * <p>최악값({@link Rating#worse})을 쓰지 않는 이유: 51곳 중 한 곳만 거칠어도 권역 전체가
     * '나쁨' 이 되어 배지가 사실상 고정된다. 안전 판단은 포인트 카드와 상세의 경고 문구가
     * 하는 일이고, 여기 배지는 <b>어디부터 볼지 고르는 데 쓰는 요약</b>이다.
     */
    static Rating averageRating(List<Rating> ratings) {
        return ratings.stream()
                .filter(Objects::nonNull)
                .mapToInt(Rating::ordinal)
                .average()
                .stream().boxed().findFirst()
                .map(average -> Rating.values()[(int) Math.round(average)])
                .orElse(null);
    }
}
