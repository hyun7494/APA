package com.apa.fishing.service;

import com.apa.fishing.domain.CatchRecord;
import com.apa.fishing.domain.Species;
import com.apa.fishing.dto.CollectionEntryResponse;
import com.apa.fishing.repository.CatchRecordRepository;
import com.apa.fishing.repository.SpeciesRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 도감 집계 (기획서 v2 4-2 {@code GET /fishing/me/collection}).
 *
 * <p><b>진행도 요약 테이블은 두지 않는다.</b> 어종 마스터와 내 기록을 매번 합쳐 만든다 —
 * 사용자당 조과가 수천 건을 넘길 일이 없고, 요약 테이블을 두면 등록·삭제마다 동기화할 자리가
 * 생겨 "도감 칸은 채워졌는데 진행률은 그대로"인 어긋남이 난다 (기획서 3-3).
 *
 * <p><b>여기는 로그인 사용자 전용이다.</b> 비로그인 도감(전 칸 잠김)은 이 경로가 아니라
 * {@code GET /fishing/species} 가 담당한다 — 프론트가 401 을 받으면 마스터로 갈아타 잠긴 칸을
 * 조립한다. 같은 정보를 두 경로가 각자 계산하지 않게 갈라 둔 것이다 (기획서 4-2 / 5-5).
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CollectionService {

    private final SpeciesRepository speciesRepository;
    private final CatchRecordRepository catchRepository;

    /** 도감 그리드. 순서는 어종 마스터의 {@code display_order} 고정이다 — 칸 위치가 흔들리면 안 된다. */
    public List<CollectionEntryResponse> myCollection(Long userId) {
        List<Species> master = speciesRepository.findByActiveTrueOrderByDisplayOrderAscIdAsc();
        Map<Long, List<CatchRecord>> mine = catchesBySpecies(userId);
        return master.stream()
                .map(species -> CollectionEntryResponse.of(
                        species, mine.getOrDefault(species.getId(), List.of())))
                .toList();
    }

    /**
     * 도감 칸 하나. <b>비활성 종도 준다</b> — 마스터에서 내린 종이라도 이미 등록한 사용자의 칸은
     * 남아 있어야 한다 ({@link SpeciesService#findOne} 과 같은 판단).
     */
    public CollectionEntryResponse myEntry(Long userId, Long speciesId) {
        Species species = speciesRepository.findById(speciesId)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "어종을 찾을 수 없습니다: " + speciesId));

        return CollectionEntryResponse.of(
                species, catchRepository.findByUserAndSpeciesLatest(userId, speciesId));
    }

    /** 진행률의 분자. 같은 종을 여러 번 잡아도 칸은 하나다. */
    public long ownedCount(Long userId) {
        return catchRepository.countOwnedSpecies(userId);
    }

    /** 진행률의 분모. */
    public long totalCount() {
        return speciesRepository.countByActiveTrue();
    }

    private Map<Long, List<CatchRecord>> catchesBySpecies(Long userId) {
        return catchRepository.findAllByUser(userId).stream()
                .collect(Collectors.groupingBy(record -> record.getSpecies().getId()));
    }
}
