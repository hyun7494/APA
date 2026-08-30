package com.apa.fishing.dto;

import com.apa.fishing.domain.FishingRegion;
import com.apa.fishing.domain.Rating;

/**
 * 계약서 3-1. {@code preview*} 는 기획서 스키마에 없는 파생 필드로,
 * 지역 검색 화면의 그룹 미리보기 배지에 쓰인다. 값은 <b>권역 안 포인트들의 평균</b>이다 —
 * 예전엔 첫 포인트 값을 그대로 썼는데, 권역이 커진 뒤로는 그게 한 포인트의 이상값에
 * 통째로 휘둘렸다 (RegionService 주석 참고).
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

    public static RegionGroupResponse of(FishingRegion region,
                                         Rating averageRating,
                                         Double averageWaterTemp,
                                         int spotCount) {
        return new RegionGroupResponse(
                region.getId(),
                region.getName(),
                region.getArea(),
                averageRating == null ? null : averageRating.name(),
                averageWaterTemp,
                spotCount
        );
    }
}
