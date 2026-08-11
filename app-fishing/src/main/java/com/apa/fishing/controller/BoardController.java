package com.apa.fishing.controller;

import com.apa.fishing.dto.PostResponse;
import com.apa.fishing.service.BoardService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
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
}
