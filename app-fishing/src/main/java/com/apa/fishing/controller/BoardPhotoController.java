package com.apa.fishing.controller;

import com.apa.fishing.service.PhotoScope;
import com.apa.fishing.service.PhotoStorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;

/**
 * 게시글 사진 서빙. <b>인증이 없다.</b>
 *
 * <p>조과 인증샷({@link PhotoController})과 갈라 둔 이유가 이것이다. 그쪽은 본인만 보는 기록이라
 * 매 요청 소유자를 확인하지만, 게시글 사진은 <b>글쓴이가 공개하려고 붙인 것</b>이고 게시판은
 * 비로그인도 읽는다 (기획서 5-5). 인증을 걸면 <b>로그인하지 않은 사람에게는 글의 사진이
 * 전부 깨져 보인다.</b>
 *
 * <p>★ <b>파일은 이제 다른 폴더에 저장된다.</b> 예전에는 한 폴더에 섞어 두고 접근 정책을
 * URL 앞부분으로만 갈랐는데, 그러면 <b>여기로 조과 인증샷을 요청하는 것을 막을 수가 없다.</b>
 * 실제로 뚫렸다 — 소유자 확인이 걸린 경로에서는 401·404 인 파일이 여기서는 200 이었다.
 * 폴더가 경계가 되면 이 컨트롤러는 비공개 사진의 존재 자체를 모른다 ({@link PhotoScope}).
 */
@RestController
@RequestMapping(BoardPhotoController.PATH)
@RequiredArgsConstructor
public class BoardPhotoController {

    static final String PATH = "/fishing/board/photos";

    /** 내용이 바뀌지 않는 파일이다 (수정은 새 UUID 를 만든다). */
    private static final Duration CACHE_TTL = Duration.ofDays(30);

    private final PhotoStorageService photoStorage;

    /**
     * @param thumb 목록 카드용 320px 판. 썸네일이 없으면 원본으로 떨어진다
     */
    @GetMapping("/{fileName}")
    public ResponseEntity<byte[]> photo(@PathVariable String fileName,
                                        @RequestParam(defaultValue = "false") boolean thumb) {
        // ★ 범위를 못박는다. 이 경로에는 인증이 없으므로, 여기서 조과 폴더에 닿을 수
        //   있으면 그 순간 **본인만 보는 인증샷이 공개된다.** 실제로 그랬다 —
        //   같은 파일을 `/fishing/me/photos/` 로는 401·404, 여기로는 200 이었다.
        return photoStorage.load(PhotoScope.BOARD, fileName, thumb)
                .map(bytes -> ResponseEntity.ok()
                        .contentType(MediaType.IMAGE_JPEG)
                        .cacheControl(CacheControl.maxAge(CACHE_TTL).cachePublic())
                        .body(bytes))
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "사진을 찾을 수 없습니다"));
    }
}
