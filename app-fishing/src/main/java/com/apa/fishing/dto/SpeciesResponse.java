package com.apa.fishing.dto;

import com.apa.fishing.domain.Species;

import java.math.BigDecimal;

/**
 * 어종 마스터 응답. 필드 이름은 프론트 {@code Species.fromJson}
 * ({@code fishing_app/lib/models/species.dart}) 에 맞춰져 있다 — 계약서는 아직 Rev 1 이라
 * 도감 섹션이 없고, <b>프론트 구현이 기준</b>이다.
 *
 * <p>null 을 그대로 내보내도 되는 필드들이다: 프론트가 {@code nameSci}·{@code description} 은
 * 빈 문자열로, {@code minLegalSize}·{@code closedSeason}·{@code season}·{@code illustPath} 는
 * "해당 행을 숨긴다"로 다룬다. 없는 값을 "-" 같은 문자열로 채우면 도감 상세 표에 빈 줄이 남는다.
 * (지수 쪽 {@link SpotResponse} 가 "-" 로 채우는 것과 반대 방향인데, 저긴 항상 있어야 하는
 * 관측값이고 여긴 종마다 없는 게 정상인 정보라 그렇다)
 */
public record SpeciesResponse(
        Long id,
        String name,
        String nameSci,
        String habitat,
        String rarity,
        Double minLegalSize,
        String closedSeason,
        String season,
        String description,
        String illustPath,
        int displayOrder,
        boolean isActive
) {

    public static SpeciesResponse from(Species species) {
        return new SpeciesResponse(
                species.getId(),
                species.getName(),
                species.getNameSci(),
                species.getHabitat().name(),
                species.getRarity().name(),
                toDouble(species.getMinLegalSize()),
                species.getClosedSeason(),
                species.getSeason(),
                species.getDescription(),
                species.getIllustPath(),
                species.getDisplayOrder(),
                species.isActive()
        );
    }

    private static Double toDouble(BigDecimal value) {
        return value == null ? null : value.doubleValue();
    }
}
