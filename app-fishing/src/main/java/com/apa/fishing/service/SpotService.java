package com.apa.fishing.service;

import com.apa.fishing.dto.SpotResponse;
import com.apa.fishing.repository.FishingSpotRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class SpotService {

    private final FishingSpotRepository spotRepository;

    /** regionGroupId 가 없으면 전체를 준다 (지역 필터 없는 화면·수동 확인용). */
    public List<SpotResponse> findByRegion(Long regionGroupId) {
        var spots = regionGroupId == null
                ? spotRepository.findAllWithRegion()
                : spotRepository.findByRegionId(regionGroupId);
        return spots.stream().map(SpotResponse::from).toList();
    }

    public SpotResponse findOne(Long id) {
        return spotRepository.findWithRegionById(id)
                .map(SpotResponse::from)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "포인트를 찾을 수 없습니다: " + id));
    }
}
