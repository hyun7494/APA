package com.apa.fishing.service;

import com.apa.fishing.domain.CatchRecord;
import com.apa.fishing.domain.FishingRegion;
import com.apa.fishing.domain.Species;
import com.apa.fishing.dto.CatchCreateRequest;
import com.apa.fishing.dto.CatchResponse;
import com.apa.fishing.dto.CatchResultResponse;
import com.apa.fishing.repository.CatchRecordRepository;
import com.apa.fishing.repository.FishingRegionRepository;
import com.apa.fishing.repository.SpeciesRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

/**
 * 조과 등록·조회·수정·삭제 (기획서 v2 4-2).
 *
 * <p><b>삭제는 필수 기능이다.</b> 어종을 잘못 골라 등록한 걸 되돌릴 수 없으면 도감 전체의 신뢰가
 * 무너진다. 해당 어종의 마지막 기록이 지워지면 도감 칸도 자동으로 잠긴다 — 별도 처리가 아니라
 * {@link CollectionService} 가 매번 다시 세기 때문에 그냥 그렇게 된다 (기획서 3-3).
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CatchService {

    private final CatchRecordRepository catchRepository;
    private final SpeciesRepository speciesRepository;
    private final FishingRegionRepository regionRepository;
    private final PhotoStorageService photoStorage;
    private final CollectionService collectionService;

    public List<CatchResponse> myCatches(Long userId, Long speciesId) {
        List<CatchRecord> records = speciesId == null
                ? catchRepository.findByUserLatest(userId)
                : catchRepository.findByUserAndSpeciesLatest(userId, speciesId);
        return records.stream().map(CatchResponse::from).toList();
    }

    /**
     * 조과 등록.
     *
     * <p>{@code firstCatch} 는 <b>저장 전에</b> 판정한다 — 저장 후에 물으면 방금 넣은 레코드 때문에
     * 항상 false 가 되어 도감 획득 연출이 영영 안 뜬다.
     */
    @Transactional
    public CatchResultResponse register(Long userId, CatchCreateRequest request, MultipartFile photo) {
        Species species = findSpecies(request.speciesId());
        boolean firstCatch = !catchRepository.existsByUserIdAndSpeciesId(userId, species.getId());

        String photoUrl = storeIfPresent(photo);
        try {
            CatchRecord record = CatchRecord.create(
                    userId, species, request.lengthCm(), request.caughtAt());
            record.describe(request.weightG(), findRegion(request.regionGroupId()),
                    request.spotName(), request.memo());
            record.attachPhoto(photoUrl);

            CatchRecord saved = catchRepository.save(record);
            return CatchResultResponse.of(saved, firstCatch,
                    collectionService.ownedCount(userId), collectionService.totalCount());
        } catch (RuntimeException e) {
            // 롤백은 DB 행만 되돌린다. 방금 쓴 파일은 아무도 참조하지 않는 채 디스크에 남으므로
            // 여기서 직접 치운다.
            deleteIfPresent(photoUrl);
            throw e;
        }
    }

    /**
     * 기록 수정. 사진을 새로 보내지 않으면 기존 사진을 그대로 둔다 — 길이 오타 하나 고치자고
     * 인증샷을 다시 고르게 만들 이유가 없다.
     */
    @Transactional
    public CatchResponse update(Long userId, Long id, CatchCreateRequest request, MultipartFile photo) {
        CatchRecord record = findOwned(userId, id);

        // 어종 변경도 허용한다. 잘못 고른 어종을 고치는 건 삭제 다음으로 흔한 되돌리기다.
        Species species = findSpecies(request.speciesId());
        String oldPhotoUrl = record.getPhotoUrl();
        String newPhotoUrl = storeIfPresent(photo);

        try {
            record.reviseMeasurement(request.lengthCm(), request.caughtAt());
            record.describe(request.weightG(), findRegion(request.regionGroupId()),
                    request.spotName(), request.memo());
            if (newPhotoUrl != null) {
                record.attachPhoto(newPhotoUrl);
            }
            record.changeSpecies(species);

            CatchResponse response = CatchResponse.from(record);
            // 커밋된 뒤에야 옛 사진이 정말 안 쓰이는 것이지만, 트랜잭션 동기화까지 걸 만한
            // 무게는 아니다. 실패해도 delete 는 조용히 넘어가고 파일만 남는다.
            if (newPhotoUrl != null) {
                deleteIfPresent(oldPhotoUrl);
            }
            return response;
        } catch (RuntimeException e) {
            deleteIfPresent(newPhotoUrl);
            throw e;
        }
    }

    /** 기획서 3-3 이 못박은 필수 기능. 사진 파일도 함께 지운다. */
    @Transactional
    public void delete(Long userId, Long id) {
        CatchRecord record = findOwned(userId, id);
        String photoUrl = record.getPhotoUrl();
        catchRepository.delete(record);
        deleteIfPresent(photoUrl);
    }

    /** 사진 서빙의 소유자 확인. 인증샷은 기본적으로 본인만 열람이다 (기획서 7장). */
    public boolean ownsPhoto(Long userId, String photoUrl) {
        return catchRepository.existsByUserIdAndPhotoUrl(userId, photoUrl);
    }

    /**
     * <b>없는 기록과 남의 기록을 구분하지 않고 둘 다 404 로 낸다.</b> 403 을 내면 "그 id 는 존재하며
     * 내 것이 아니다"를 알려주는 셈이라, id 를 훑어 남이 몇 건을 등록했는지 셀 수 있다.
     */
    private CatchRecord findOwned(Long userId, Long id) {
        return catchRepository.findWithSpeciesById(id)
                .filter(record -> record.ownedBy(userId))
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "조과 기록을 찾을 수 없습니다: " + id));
    }

    private Species findSpecies(Long speciesId) {
        return speciesRepository.findById(speciesId)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.BAD_REQUEST, "어종을 찾을 수 없습니다: " + speciesId));
    }

    /** 장소는 선택이고 등록된 포인트가 아닐 수도 있다. 없는 지역 id 는 무시하고 자유 입력만 남긴다. */
    private FishingRegion findRegion(Long regionGroupId) {
        return regionGroupId == null ? null : regionRepository.findById(regionGroupId).orElse(null);
    }

    private String storeIfPresent(MultipartFile photo) {
        return (photo == null || photo.isEmpty()) ? null : photoStorage.store(photo);
    }

    private void deleteIfPresent(String photoUrl) {
        if (photoUrl != null) {
            photoStorage.delete(photoUrl);
        }
    }
}
