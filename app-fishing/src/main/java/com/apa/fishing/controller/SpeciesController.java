package com.apa.fishing.controller;

import com.apa.fishing.dto.SpeciesResponse;
import com.apa.fishing.service.SpeciesService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 어종 마스터 조회 (기획서 v2 4-2 도감). <b>비로그인도 볼 수 있다</b> — 비로그인 사용자에게는
 * 전 칸이 미등록 상태인 마스터 도감을 보여주고, 조과 등록을 누를 때만 로그인을 요구한다(5-5).
 *
 * <p>기획서에는 "로그인 시 owned 필드 포함"이라고 적혀 있지만 여기서는 넣지 않는다.
 * 내 획득 상태는 {@code GET /fishing/me/collection} 이 담당한다 — 프론트도 그렇게 갈라서 부르고,
 * 같은 정보를 두 엔드포인트가 각자 계산하면 어긋날 자리만 생긴다.
 *
 * <p>목록은 반드시 순수 JSON 배열이다 ({@link RegionController} 와 같은 이유).
 */
@RestController
@RequestMapping("/fishing/species")
@RequiredArgsConstructor
public class SpeciesController {

    private final SpeciesService speciesService;

    @GetMapping
    public List<SpeciesResponse> list() {
        return speciesService.findAll();
    }

    @GetMapping("/{id}")
    public SpeciesResponse detail(@PathVariable Long id) {
        return speciesService.findOne(id);
    }
}
