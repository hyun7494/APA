package com.apa.fishing.controller;

import com.apa.fishing.dto.PostResponse;
import com.apa.fishing.service.BoardService;
import lombok.RequiredArgsConstructor;
import com.apa.common.security.AuthenticatedUser;
import com.apa.fishing.dto.PostCreateRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/** 계약서 3-6. 전체 탭에서는 tag 파라미터 자체가 오지 않는다. */
@RestController
@RequestMapping("/fishing/board")
@RequiredArgsConstructor
public class BoardController {

    private final BoardService boardService;

    /**
     * regionGroupId 는 계약서에 있지만 프론트가 아직 보내지 않는다 (지역별 필터 UI 미구현).
     * 게시글에 지역이 생겼으므로 서버 쪽은 지금 지원해둔다.
     */
    @GetMapping
    public List<PostResponse> list(@RequestParam(required = false) String tag,
                                   @RequestParam(required = false) Long regionGroupId) {
        return boardService.findPosts(tag, regionGroupId);
    }
    /**
     * 글쓰기 (계약서 3-8).
     *
     * <p><b>인증 필수다.</b> SecurityConfig 가 {@code POST /fishing/board/**} 를 막고 있어
     * 비로그인은 401 을 받는다 — 목록 조회(GET)는 그대로 공개다 (기획서 5-5).
     *
     * <p>작성자는 요청 본문이 아니라 <b>토큰에서</b> 가져간다. 본문으로 받으면 아무나
     * 남의 이름으로 쓸 수 있다.
     */
    @PostMapping
    public ResponseEntity<PostResponse> write(@AuthenticationPrincipal AuthenticatedUser user,
                                              @RequestBody PostCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(boardService.write(user, request));
    }
}