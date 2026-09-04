package com.apa.fishing.controller;

import com.apa.common.security.AuthenticatedUser;
import com.apa.fishing.service.CatchService;
import com.apa.fishing.service.PhotoScope;
import com.apa.fishing.service.PhotoStorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;

/**
 * 조과 인증샷 서빙.
 *
 * <p><b>정적 리소스로 열지 않고 컨트롤러를 두는 이유는 소유자 확인이다.</b> 등록 사진은 기본적으로
 * 본인만 열람이다(기획서 7장). 파일명이 UUID 라 추측은 어렵지만, 추측 불가는 접근 제어가 아니다 —
 * 한 번 유출된 URL 이 영구 공개 링크가 되는 걸 막으려면 매 요청 확인이 필요하다.
 *
 * <p>경로가 {@code /fishing/me/**} 아래라 SecurityConfig 가 비로그인을 이미 401 로 끊는다.
 *
 * <p><b>게시판 공유(v1.5)를 붙일 때는 여기를 다시 봐야 한다.</b> 공유된 사진은 남이 봐야 하므로
 * "공개로 표시된 기록"이라는 개념이 생기고, 그때 이 소유자 확인이 그 플래그까지 봐야 한다.
 */
@RestController
@RequestMapping(PhotoController.PATH)
@RequiredArgsConstructor
public class PhotoController {

    static final String PATH = "/fishing/me/photos";

    /** 내용이 바뀌지 않는 파일이다 (수정은 새 UUID 를 만든다). 도감 그리드가 40칸을 매번 받지 않게 한다. */
    private static final Duration CACHE_TTL = Duration.ofDays(30);

    private final PhotoStorageService photoStorage;
    private final CatchService catchService;

    /**
     * @param thumb 도감 그리드용 320px 판. 썸네일이 없으면 원본으로 떨어진다
     */
    @GetMapping("/{fileName}")
    public ResponseEntity<byte[]> photo(@AuthenticationPrincipal AuthenticatedUser user,
                                        @PathVariable String fileName,
                                        @RequestParam(defaultValue = "false") boolean thumb) {

        // 남의 사진과 없는 사진을 구분하지 않는다 — 403 과 404 를 가르면 어떤 파일명이 존재하는지
        // 알려주는 셈이다 (CatchService.findOwned 와 같은 판단).
        if (!catchService.ownsPhoto(user.userId(), PhotoStorageService.PUBLIC_PATH + fileName)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "사진을 찾을 수 없습니다");
        }

        return photoStorage.load(PhotoScope.CATCH, fileName, thumb)
                .map(bytes -> ResponseEntity.ok()
                        .contentType(MediaType.IMAGE_JPEG)
                        // 본인만 보는 사진이라 공유 캐시에 남으면 안 된다
                        .cacheControl(CacheControl.maxAge(CACHE_TTL).cachePrivate())
                        .body(bytes))
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "사진을 찾을 수 없습니다"));
    }
}
