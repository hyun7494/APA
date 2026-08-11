package com.apa.fishing.dto;

import com.apa.fishing.domain.FishingRegion;
import com.apa.fishing.domain.FishingSpot;

/**
 * 계약서 3-1. {@code preview*} 는 기획서 스키마에 없는 파생 필드로,
 * 지역 검색 화면의 그룹 미리보기 배지에 쓰인다. 값은 그룹의 첫 포인트 것을 그대로 쓴다.
 * null 이면 프론트가 배지를 숨기므로 포인트가 없는 지역은 그대로 비워 보낸다.
 */
public record RegionGroupResponse(
        Long id,
        String name,
        String area,
        String previewRating,
        Double previewWaterTemp,
        int spotCount
) {

    public static RegionGroupResponse of(FishingRegion region, FishingSpot firstSpot, int spotCount) {
        return new RegionGroupResponse(
                region.getId(),
                region.getName(),
                region.getArea(),
                firstSpot == null ? null : firstSpot.getRating(),
                firstSpot == null || firstSpot.getWaterTemp() == null
                        ? null : firstSpot.getWaterTemp().doubleValue(),
                spotCount
        );
    }
}
