package com.apa.fishing.controller;

import com.apa.fishing.dto.RegionGroupResponse;
import com.apa.fishing.service.RegionService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 계약서 3-1, 3-2.
 * 목록은 반드시 순수 JSON 배열이다 — {@code Page<T>} 를 반환하면 프론트의
 * {@code List<dynamic>} 캐스팅이 깨진다.
 */
@RestController
@RequestMapping("/fishing/regions")
@RequiredArgsConstructor
public class RegionController {

    private final RegionService regionService;

    @GetMapping
    public List<RegionGroupResponse> list() {
        return regionService.findAll();
    }

    @GetMapping("/search")
    public List<RegionGroupResponse> search(@RequestParam(required = false) String q) {
        return regionService.search(q);
    }
}
