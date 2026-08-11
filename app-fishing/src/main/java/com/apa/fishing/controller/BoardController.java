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
     * regionGroupId 는 계약서에 있지만 현재 프론트가 보내지 않고, 지역별 필터도 Step 8에서
     * 실제 테이블이 생긴 뒤에 붙인다. 지금 받아도 무시되므로 파라미터를 두지 않는다.
     */
    @GetMapping
    public List<PostResponse> list(@RequestParam(required = false) String tag) {
        return boardService.findPosts(tag);
    }
}
