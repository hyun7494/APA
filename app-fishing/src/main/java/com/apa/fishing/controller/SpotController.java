package com.apa.fishing.controller;

import com.apa.fishing.dto.SpotResponse;
import com.apa.fishing.service.SpotService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
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
    /** 위치 검색이 한 번에 주는 곳 수. 더 주면 목록을 훑는 일이 되어 버린다. */
    private static final int NEARBY_LIMIT = 10;

    /**
     * 셋 중 하나로 동작한다 — {@code lat}·{@code lon} 이 오면 <b>가까운 순</b>,
     * {@code q} 가 오면 <b>이름 검색</b>, 없으면 지역 목록이다.
     *
     * <p>엔드포인트를 따로 파지 않은 이유는 응답이 같은 {@code Spot} 이라서다 —
     * 프론트가 파싱을 한 번만 짜면 된다.
     */
    @GetMapping
    public List<SpotResponse> list(@RequestParam(required = false) Long regionGroupId,
                                   @RequestParam(required = false) String q,
                                   @RequestParam(required = false) Double lat,
                                   @RequestParam(required = false) Double lon) {
        if (lat != null && lon != null) {
            return spotService.findNearby(lat, lon, NEARBY_LIMIT);
        }
        return q == null || q.isBlank()
                ? spotService.findByRegion(regionGroupId)
                : spotService.searchByName(q);
    }

    /**
     * 홈 요약 카드에 쓸 오늘 가장 좋은 포인트 한 곳 (계약서 3-3-1).
     *
     * <p>⚠️ <b>{@code /{id}} 보다 위에 둔다.</b> 아래에 두면 {@code Long id} 파싱이
     * "featured" 에서 먼저 터진다 — 앱 라우터에서 {@code /board/new} 를
     * {@code /board/:id} 앞에 둬야 했던 것과 같은 함정이다.
     *
     * @return 포인트가 없으면 204
     */
    @GetMapping("/featured")
    public ResponseEntity<SpotResponse> featured() {
        SpotResponse spot = spotService.findFeatured();
        return spot == null ? ResponseEntity.noContent().build() : ResponseEntity.ok(spot);
    }

    @GetMapping("/{id}")
    public SpotResponse detail(@PathVariable Long id) {
        return spotService.findOne(id);
    }
}
