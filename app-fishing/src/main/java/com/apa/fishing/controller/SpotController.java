package com.apa.fishing.controller;

import com.apa.fishing.dto.SpotResponse;
import com.apa.fishing.service.SpotService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/** 계약서 3-3, 3-4. */
@RestController
@RequestMapping("/fishing/spots")
@RequiredArgsConstructor
public class SpotController {

    private final SpotService spotService;

    /**
     * {@code q} 가 오면 <b>이름 검색</b>이고, 없으면 지역 목록이다.
     *
     * <p>엔드포인트를 따로 파지 않은 이유는 응답이 같은 {@code Spot} 이라서다 —
     * 프론트가 파싱을 한 번만 짜면 된다.
     */
    @GetMapping
    public List<SpotResponse> list(@RequestParam(required = false) Long regionGroupId,
                                   @RequestParam(required = false) String q) {
        return q == null || q.isBlank()
                ? spotService.findByRegion(regionGroupId)
                : spotService.searchByName(q);
    }

    @GetMapping("/{id}")
    public SpotResponse detail(@PathVariable Long id) {
        return spotService.findOne(id);
    }
}
