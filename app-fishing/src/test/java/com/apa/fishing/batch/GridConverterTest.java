package com.apa.fishing.batch;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 기상청이 공개한 지점별 격자표의 알려진 값으로 변환식을 검증한다.
 * 여기가 어긋나면 배치가 엉뚱한 지역의 예보를 가져오는데, 응답은 정상이라 알아채기 어렵다.
 */
class GridConverterTest {

    @Test
    @DisplayName("서울 종로구 → (60, 127)")
    void seoul() {
        assertThat(GridConverter.toGrid(37.5665, 126.9780))
                .isEqualTo(new GridConverter.Grid(60, 127));
    }

    @Test
    @DisplayName("제주 → (53, 38)")
    void jeju() {
        assertThat(GridConverter.toGrid(33.4996, 126.5312))
                .isEqualTo(new GridConverter.Grid(53, 38));
    }

    @Test
    @DisplayName("격자는 5km 단위라 가까운 두 지점은 같은 칸에 들어간다")
    void nearbyPointsShareGrid() {
        // 기장 학리와 대변항은 3km 남짓 떨어져 있다.
        GridConverter.Grid hakri = GridConverter.toGrid(35.2409, 129.2260);
        GridConverter.Grid daebyeon = GridConverter.toGrid(35.2181, 129.2233);

        assertThat(hakri.nx()).isEqualTo(daebyeon.nx());
        assertThat(Math.abs(hakri.ny() - daebyeon.ny())).isLessThanOrEqualTo(1);
    }
}
