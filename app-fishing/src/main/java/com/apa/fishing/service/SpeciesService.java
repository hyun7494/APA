package com.apa.fishing.service;

import com.apa.fishing.dto.SpeciesResponse;
import com.apa.fishing.repository.SpeciesRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class SpeciesService {

    private final SpeciesRepository speciesRepository;

    /** 도감 그리드의 분모다. 내린 종 수가 곧 진행률의 total 이 된다. */
    public List<SpeciesResponse> findAll() {
        return speciesRepository.findByActiveTrueOrderByDisplayOrderAscIdAsc().stream()
                .map(SpeciesResponse::from)
                .toList();
    }

    /**
     * 상세는 <b>비활성 종도 준다.</b> 마스터에서 내린 종이라도 이미 등록한 사용자의 조과 기록과
     * 도감 칸은 남아 있어야 하고, 그 칸을 눌렀을 때 404 가 나면 기록이 사라진 것처럼 보인다.
     */
    public SpeciesResponse findOne(Long id) {
        return speciesRepository.findById(id)
                .map(SpeciesResponse::from)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "어종을 찾을 수 없습니다: " + id));
    }
}
