package com.apa.fishing.dto;

import com.apa.fishing.domain.CatchRecord;
import com.apa.fishing.domain.Species;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;

/**
 * 도감 한 칸 — 어종 마스터 + 그 어종에 대한 내 획득 상태 (기획서 v2 2-3).
 *
 * <p>프론트 {@code CollectionEntry} 는 {@code catchCount > 0} 하나로 획득 여부를 판정한다.
 * 서버가 {@code owned} 를 따로 내리지 않는 이유다 — 같은 사실을 두 필드로 말하면 어긋날 자리가 생긴다.
 *
 * <p>비로그인 사용자에게는 전 칸이 {@code catchCount = 0} 인 마스터 도감이 나간다.
 * 잠긴 칸이라도 <b>어종 이름은 가리지 않는다</b> — 뭘 잡아야 할지 알아야 다음 출조 동기가 생긴다(2-3).
 */
public record CollectionEntryResponse(
        SpeciesResponse species,
        int catchCount,
        Double bestLengthCm,
        String coverPhotoUrl,
        LocalDateTime firstCaughtAt
) {

    /** 아직 만나지 못한 칸. */
    public static CollectionEntryResponse locked(Species species) {
        return new CollectionEntryResponse(SpeciesResponse.from(species), 0, null, null, null);
    }

    /**
     * 한 어종의 내 기록을 모아 칸 하나를 만든다.
     *
     * <p><b>표지와 최고 기록은 가장 큰 개체의 것이다</b> (최신이 아니다). 도감 칸은 기록장이 아니라
     * 자랑이라, 어제 잡은 20cm 가 작년의 45cm 를 밀어내면 칸이 초라해진다. 프론트 mock 구현도
     * 같은 규칙으로 조립하므로 더미↔실서버 전환에서 칸이 바뀌지 않는다.
     */
    public static CollectionEntryResponse of(Species species, List<CatchRecord> mine) {
        if (mine.isEmpty()) {
            return locked(species);
        }

        CatchRecord best = mine.stream()
                .max(Comparator.comparing(CatchRecord::getLengthCm))
                .orElseThrow();
        LocalDateTime first = mine.stream()
                .map(CatchRecord::getCaughtAt)
                .min(Comparator.naturalOrder())
                .orElseThrow();

        return new CollectionEntryResponse(
                SpeciesResponse.from(species),
                mine.size(),
                CatchResponse.toDouble(best.getLengthCm()),
                // 사진 없이 등록된 기록(피커 미연동 경로)은 표지가 될 수 없다.
                // 빈 문자열을 내보내면 프론트가 그걸 URL 로 알고 깨진 이미지를 그린다.
                blankToNull(best.getPhotoUrl()),
                first
        );
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value;
    }
}
