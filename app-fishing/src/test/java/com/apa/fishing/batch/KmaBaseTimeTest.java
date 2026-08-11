package com.apa.fishing.batch;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;

class KmaBaseTimeTest {

    @Test
    @DisplayName("발표 10분 이내면 아직 데이터가 없으므로 직전 회차를 쓴다")
    void withinPublishBufferFallsBack() {
        KmaBaseTime.BaseTime resolved = KmaBaseTime.resolve(LocalDateTime.of(2026, 8, 12, 14, 5));

        assertThat(resolved.baseTime()).isEqualTo("1100");
        assertThat(resolved.baseDate()).isEqualTo(LocalDate.of(2026, 8, 12));
    }

    @Test
    @DisplayName("발표 10분이 지나면 그 회차를 쓴다")
    void afterPublishBufferUsesCurrentSlot() {
        KmaBaseTime.BaseTime resolved = KmaBaseTime.resolve(LocalDateTime.of(2026, 8, 12, 14, 20));

        assertThat(resolved.baseTime()).isEqualTo("1400");
        assertThat(resolved.baseDate()).isEqualTo(LocalDate.of(2026, 8, 12));
    }

    @Test
    @DisplayName("자정~02:10 사이는 어제 2300 회차다 — 날짜 롤오버를 놓치기 쉽다")
    void beforeFirstSlotRollsBackToYesterday() {
        KmaBaseTime.BaseTime resolved = KmaBaseTime.resolve(LocalDateTime.of(2026, 8, 12, 0, 30));

        assertThat(resolved.baseTime()).isEqualTo("2300");
        assertThat(resolved.baseDate()).isEqualTo(LocalDate.of(2026, 8, 11));
    }

    @Test
    @DisplayName("02:05 도 아직 어제 2300 회차다 (버퍼 때문에 02시 회차로 못 넘어간다)")
    void justBeforeBufferBoundary() {
        KmaBaseTime.BaseTime resolved = KmaBaseTime.resolve(LocalDateTime.of(2026, 8, 12, 2, 5));

        assertThat(resolved.baseTime()).isEqualTo("2300");
        assertThat(resolved.baseDate()).isEqualTo(LocalDate.of(2026, 8, 11));
    }

    @Test
    @DisplayName("baseDate 는 공공 API 형식(yyyyMMdd)으로 나간다")
    void formatsBaseDate() {
        KmaBaseTime.BaseTime resolved = KmaBaseTime.resolve(LocalDateTime.of(2026, 8, 12, 23, 30));

        assertThat(resolved.baseDateString()).isEqualTo("20260812");
    }
}
