package com.apa.fishing.controller;

import com.apa.common.security.AuthenticatedUser;
import com.apa.fishing.dto.CatchCreateRequest;
import com.apa.fishing.dto.CatchResponse;
import com.apa.fishing.dto.CatchResultResponse;
import com.apa.fishing.service.CatchService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

/**
 * 내 조과 기록 (기획서 v2 4-2). 전부 인증 필요 — {@code /fishing/me/**} 를 SecurityConfig 가 막는다.
 *
 * <p><b>필드를 JSON 한 덩어리가 아니라 폼 필드로 받는다.</b> 기획서는 {@code photo: file, data: JSON}
 * 형태를 적었지만 프론트({@code RemoteFishingRepository.registerCatch})가 {@code FormData} 에
 * 값을 평평하게 담아 보낸다. 계약서는 아직 Rev 1 이라 이 부분이 없고 <b>프론트 구현이 기준</b>이다.
 *
 * <p>{@code caughtAt} 을 {@code LocalDateTime} 이 아니라 {@code String} 으로 받는 이유는
 * {@link CatchCreateRequest} 주석 참고 — 기기 시각 표기가 한 가지가 아니라서 파싱을 직접 한다.
 */
@RestController
@RequestMapping("/fishing/me/catches")
@RequiredArgsConstructor
public class CatchController {

    private final CatchService catchService;

    /** {@code speciesId} 를 주면 그 어종만. 어종 상세 화면의 "내 조과 기록" 목록이 이걸 쓴다. */
    @GetMapping
    public List<CatchResponse> myCatches(@AuthenticationPrincipal AuthenticatedUser user,
                                         @RequestParam(required = false) Long speciesId) {
        return catchService.myCatches(user.userId(), speciesId);
    }

    /**
     * 조과 등록. 응답의 {@code firstCatch} 가 true 면 프론트가 도감 획득 연출로 넘어간다.
     *
     * <p>사진이 {@code required = false} 인 이유: 기획서상 인증샷은 필수지만 프론트가 아직
     * image_picker 를 붙이지 않았다({@code FeatureFlags.enablePhotoPicker = false}).
     * 지금 필수로 막으면 유일한 클라이언트가 등록을 못 한다 — 피커가 붙으면 여기서 막는다.
     */
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public CatchResultResponse register(@AuthenticationPrincipal AuthenticatedUser user,
                                        @RequestParam Long speciesId,
                                        @RequestParam(required = false) Double lengthCm,
                                        @RequestParam(required = false) Integer weightG,
                                        @RequestParam(required = false) String caughtAt,
                                        @RequestParam(required = false) Long regionGroupId,
                                        @RequestParam(required = false) String spotName,
                                        @RequestParam(required = false) String memo,
                                        @RequestPart(required = false) List<MultipartFile> photos) {
        var request = CatchCreateRequest.of(
                speciesId, lengthCm, weightG, caughtAt, regionGroupId, spotName, memo);
        return catchService.register(user.userId(), request, photos);
    }

    /**
     * 사진 파트를 안 보내고 {@code keepPhotoUrls} 도 없으면 기존 인증샷을 그대로 둔다.
     *
     * <p>{@code keepPhotoUrls} 는 <b>남길 장의 목록</b>이다 (파트를 여러 번 보낸다).
     * 안 보내면 사진을 건드리지 않고, 빈 값이면 다 뗀다 — 둘을 구분해야 길이만 고치는
     * 흔한 경우가 사진을 날리지 않는다. 목록에 <b>이 기록의 것이 아닌 URL 이 섞이면 400</b> 이다
     * ({@code CatchService.requireOwnPhotos}) — 조용히 걸러 내면 결과가 삭제라서다.
     *
     * <p>새로 올린 장은 남긴 장 <b>뒤에</b> 붙는다. 최종 목록의 첫 장이 도감 칸의 표지다.
     */
    @PutMapping(path = "/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public CatchResponse update(@AuthenticationPrincipal AuthenticatedUser user,
                                @PathVariable Long id,
                                @RequestParam Long speciesId,
                                @RequestParam(required = false) Double lengthCm,
                                @RequestParam(required = false) Integer weightG,
                                @RequestParam(required = false) String caughtAt,
                                @RequestParam(required = false) Long regionGroupId,
                                @RequestParam(required = false) String spotName,
                                @RequestParam(required = false) String memo,
                                @RequestParam(required = false) List<String> keepPhotoUrls,
                                @RequestPart(required = false) List<MultipartFile> photos) {
        var request = CatchCreateRequest.of(
                speciesId, lengthCm, weightG, caughtAt, regionGroupId, spotName, memo);
        return catchService.update(user.userId(), id, request, keepPhotoUrls, photos);
    }

    /**
     * 기획서 3-3 이 못박은 필수 기능이다. 해당 어종의 마지막 기록이 지워지면 도감 칸도 다시 잠긴다
     * (도감이 매번 다시 세어지므로 별도 처리가 없다).
     */
    @DeleteMapping("/{id}")
    public void delete(@AuthenticationPrincipal AuthenticatedUser user, @PathVariable Long id) {
        catchService.delete(user.userId(), id);
    }
}
