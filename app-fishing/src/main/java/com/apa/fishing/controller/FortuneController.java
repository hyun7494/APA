package com.apa.fishing.controller;

import com.apa.fishing.dto.FortuneResponse;
import com.apa.fishing.service.FortuneService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 계약서 3-5. 비로그인도 조회 가능하고, 프론트는 항상 zodiac 쿼리를 붙여 호출한다.
 * {@code /fishing/fortune/me} (저장된 띠 기준)는 인증이 붙는 Step 9 이후다.
 */
@RestController
@RequestMapping("/fishing/fortune")
@RequiredArgsConstructor
public class FortuneController {

    private final FortuneService fortuneService;

    @GetMapping
    public FortuneResponse today(@RequestParam(required = false) String zodiac) {
        return fortuneService.findToday(zodiac);
    }
}
