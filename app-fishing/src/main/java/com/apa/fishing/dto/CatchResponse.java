package com.apa.fishing.dto;

import com.apa.fishing.domain.CatchRecord;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 조과 기록 응답. 필드 이름은 프론트 {@code CatchRecord.fromJson}
 * ({@code fishing_app/lib/models/catch_record.dart}) 에 맞췄다 — 계약서는 Rev 1 이라 도감·조과
 * 섹션이 없고 <b>프론트 구현이 기준</b>이다 ({@link SpeciesResponse} 와 같은 사정).
 *
 * <p>{@code speciesName} 을 함께 내리는 이유: 내 조과 목록은 여러 어종이 섞이는데, 이름이 없으면
 * 프론트가 목록 한 줄마다 어종 마스터를 다시 찾아야 한다.
 */
public record CatchResponse(
        Long id,
        Long speciesId,
        String speciesName,
        /** 인증샷 여러 장. 순서가 있고 첫 장이 표지다. 없으면 빈 배열. */
        List<String> photoUrls,
        Double lengthCm,
        Integer weightG,
        LocalDateTime caughtAt,
        Long regionGroupId,
        String spotName,
        String memo
) {

    public static CatchResponse from(CatchRecord record) {
        return new CatchResponse(
                record.getId(),
                record.getSpecies().getId(),
                record.getSpecies().getName(),
                List.copyOf(record.getPhotoUrls()),
                toDouble(record.getLengthCm()),
                record.getWeightG(),
                record.getCaughtAt(),
                record.getRegion() == null ? null : record.getRegion().getId(),
                record.getSpotName(),
                record.getMemo()
        );
    }

    static Double toDouble(BigDecimal value) {
        return value == null ? null : value.doubleValue();
    }
}
