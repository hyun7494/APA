package com.apa.fishing.batch;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 거리 계산. 키 없이 도는 순수 함수라 {@link GridConverter} 와 같은 자리에 둔다.
 *
 * <p>여기서 확인하는 건 "가까운 순으로 줄을 세울 수 있느냐" 지 측지학적 정밀도가 아니다.
 */
class HaversineTest {

    /** V5 가 넣어 둔 실제 포인트 좌표. */
    private static final double[] HAKRI = {35.240900, 129.226000};      // 기장 학리
    private static final double[] DAEBYEON = {35.218100, 129.223300};   // 기장 대변항 방파제
    private static final double[] YEONGJONG = {37.491300, 126.522000};  // 영종도 선착장

    @Test
    @DisplayName("같은 지점은 0")
    void samePoint() {
        assertThat(Haversine.km(HAKRI[0], HAKRI[1], HAKRI[0], HAKRI[1])).isZero();
    }

    @Test
    @DisplayName("기장 학리 ↔ 대변항은 2.5km 남짓 — V6 주석이 적어 둔 거리와 맞는다")
    void nearbyPair() {
        double km = Haversine.km(HAKRI[0], HAKRI[1], DAEBYEON[0], DAEBYEON[1]);
        assertThat(km).isBetween(2.0, 3.0);
    }

    @Test
    @DisplayName("부산 ↔ 인천은 직선 350km 안팎 (도로 거리가 아니다)")
    void farPair() {
        double km = Haversine.km(HAKRI[0], HAKRI[1], YEONGJONG[0], YEONGJONG[1]);
        assertThat(km).isBetween(340.0, 360.0);
    }

    @Test
    @DisplayName("★ 방향이 바뀌어도 같은 거리다 — 정렬 기준이라 대칭이어야 한다")
    void symmetric() {
        assertThat(Haversine.km(HAKRI[0], HAKRI[1], YEONGJONG[0], YEONGJONG[1]))
                .isEqualTo(Haversine.km(YEONGJONG[0], YEONGJONG[1], HAKRI[0], HAKRI[1]));
    }

    @Test
    @DisplayName("가까운 쪽이 언제나 더 작다")
    void ordersCorrectly() {
        double near = Haversine.km(HAKRI[0], HAKRI[1], DAEBYEON[0], DAEBYEON[1]);
        double far = Haversine.km(HAKRI[0], HAKRI[1], YEONGJONG[0], YEONGJONG[1]);
        assertThat(near).isLessThan(far);
    }
}
