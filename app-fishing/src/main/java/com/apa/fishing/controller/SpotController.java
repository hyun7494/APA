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

    @GetMapping
    public List<SpotResponse> list(@RequestParam(required = false) Long regionGroupId) {
        return spotService.findByRegion(regionGroupId);
    }

    @GetMapping("/{id}")
    public SpotResponse detail(@PathVariable Long id) {
        return spotService.findOne(id);
    }
}
