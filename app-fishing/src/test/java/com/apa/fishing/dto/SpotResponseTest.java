package com.apa.fishing.dto;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Method;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 응답으로 나갈 때의 정규화. 여기서 지키는 건 하나다 —
 * <b>없는 값을 있는 값처럼 내보내지 않는다.</b>
 */
class SpotResponseTest {

    @SuppressWarnings("unchecked")
    private static List<Integer> pad(List<Integer> forecast) throws Exception {
        Method method = SpotResponse.class.getDeclaredMethod("padForecast", List.class);
        method.setAccessible(true);
        return (List<Integer>) method.invoke(null, forecast);
    }

    @Test
    @DisplayName("★ 시간대별 예보가 없으면 빈 목록이다 — 0 여섯 개를 지어내지 않는다")
    void missingForecastIsEmptyNotZeros() throws Exception {
        // 예전엔 여기서 [0,0,0,0,0,0] 을 만들었다. 그 탓에 예보가 없는 45곳이
        // "온종일 조황 0" 그래프 위에 "06시 최적" 이라고 단언하고 있었다.
        assertThat(pad(null)).isEmpty();
    }

    @Test
    @DisplayName("여섯 칸이 다 있을 때만 그대로 내보낸다")
    void passesThroughFullForecast() throws Exception {
        List<Integer> full = List.of(55, 70, 82, 76, 68, 60);
        assertThat(pad(full)).isEqualTo(full);
    }

    @Test
    @DisplayName("★ 칸 수가 안 맞으면 채우지 않고 버린다 — 빈 칸은 '조황 0' 으로 읽힌다")
    void dropsPartialForecast() throws Exception {
        assertThat(pad(List.of(55, 70, 82))).isEmpty();
        assertThat(pad(List.of(55, 70, 82, 76, 68, 60, 44))).isEmpty();
    }
}
