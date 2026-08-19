package com.apa.fishing.repository;

import com.apa.fishing.domain.Species;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SpeciesRepository extends JpaRepository<Species, Long> {

    /**
     * 도감 그리드 순서. {@code display_order} 가 같은 값으로 겹칠 때를 대비해 id 로 한 번 더 묶는다 —
     * 정렬이 흔들리면 사용자가 외운 칸 위치가 매 조회마다 바뀐다.
     */
    List<Species> findByActiveTrueOrderByDisplayOrderAscIdAsc();

    /**
     * 도감 진행률의 분모. <b>비활성 종은 세지 않는다</b> — 그리드에 안 뜨는 칸이 분모에 있으면
     * 전부 채워도 100%가 되지 않는다.
     */
    long countByActiveTrue();
}
