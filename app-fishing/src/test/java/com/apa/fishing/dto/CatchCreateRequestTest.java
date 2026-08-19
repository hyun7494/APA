package com.apa.fishing.dto;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 등록 요청 정규화. 여기서 걸러야 할 건 <b>컬럼에 안 들어가는 값</b>뿐이다 —
 * 어종·길이의 타당성은 자기신고라 서버가 판단하지 않는다 (Rev 2 결정).
 */
class CatchCreateRequestTest {

    @Test
    @DisplayName("길이를 소수점 1자리로 반올림한다 — DECIMAL(4,1) 스케일 초과를 막는다")
    void roundsLength() {
        assertThat(request(42.36).lengthCm()).isEqualByComparingTo(new BigDecimal("42.4"));
        assertThat(request(42.0).lengthCm()).isEqualByComparingTo(new BigDecimal("42.0"));
    }

    @Test
    @DisplayName("길이가 없거나 0 이하면 400")
    void rejectsMissingLength() {
        assertThatThrownBy(() -> request(null)).isInstanceOf(ResponseStatusException.class);
        assertThatThrownBy(() -> request(0.0)).isInstanceOf(ResponseStatusException.class);
        assertThatThrownBy(() -> request(-5.0)).isInstanceOf(ResponseStatusException.class);
    }

    @Test
    @DisplayName("999.9cm 를 넘으면 400 — INSERT 가 터지기 전에 잡는다")
    void rejectsOversizedLength() {
        assertThatThrownBy(() -> request(1000.0)).isInstanceOf(ResponseStatusException.class);
    }

    @Test
    @DisplayName("금지체장보다 작아도 통과한다 — 등록을 막지 않는다")
    void allowsUndersizedFish() {
        // 막으면 사용자가 길이를 거짓으로 입력하게 되고 데이터만 나빠진다 (기획서 5-4 ③).
        // 안내는 프론트가 배너로 한다.
        assertThat(request(5.0).lengthCm()).isEqualByComparingTo(new BigDecimal("5.0"));
    }

    @Test
    @DisplayName("어종이 없으면 400")
    void rejectsMissingSpecies() {
        assertThatThrownBy(() -> CatchCreateRequest.of(null, 30.0, null, null, null, null, null))
                .isInstanceOf(ResponseStatusException.class);
    }

    @Test
    @DisplayName("오프셋 없는 로컬 시각을 읽는다 — 프론트 DateTime.toIso8601String() 의 기본형")
    void parsesLocalDateTime() {
        var parsed = caughtAt("2026-08-17T14:30:00.000");
        assertThat(parsed).isEqualTo(LocalDateTime.of(2026, 8, 17, 14, 30, 0));
    }

    @Test
    @DisplayName("Z 가 붙은 UTC 표기도 읽는다")
    void parsesInstant() {
        // UTC 로 만든 DateTime 은 toIso8601String() 이 Z 를 붙여 내보낸다.
        assertThat(caughtAt("2026-08-17T05:30:00.000Z")).isNotNull();
    }

    @Test
    @DisplayName("오프셋이 붙은 표기도 읽는다")
    void parsesOffsetDateTime() {
        assertThat(caughtAt("2026-08-17T14:30:00+09:00"))
                .isEqualTo(LocalDateTime.of(2026, 8, 17, 14, 30, 0));
    }

    @Test
    @DisplayName("못 읽는 시각은 400 이 아니라 현재 시각 — 등록 자체를 막지 않는다")
    void fallsBackToNow() {
        // 여기서 400 을 내면 사용자는 사진·길이를 다 채워 놓고 등록만 안 되는 상태에 빠진다.
        assertThat(caughtAt("어제")).isAfter(LocalDateTime.now().minusMinutes(1));
        assertThat(caughtAt(null)).isAfter(LocalDateTime.now().minusMinutes(1));
    }

    @Test
    @DisplayName("빈 문자열 장소·메모는 null 로 — '없음'과 '비워 둠'을 섞지 않는다")
    void blankToNull() {
        var request = CatchCreateRequest.of(1L, 30.0, null, null, null, "   ", "");
        assertThat(request.spotName()).isNull();
        assertThat(request.memo()).isNull();
    }

    @Test
    @DisplayName("컬럼 길이를 넘는 메모는 자르지 않고 400 — 사용자가 쓴 글이다")
    void rejectsOverlongText() {
        String longMemo = "가".repeat(301);
        assertThatThrownBy(() -> CatchCreateRequest.of(1L, 30.0, null, null, null, null, longMemo))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("300");

        String longSpot = "가".repeat(51);
        assertThatThrownBy(() -> CatchCreateRequest.of(1L, 30.0, null, null, null, longSpot, null))
                .isInstanceOf(ResponseStatusException.class);
    }

    private static CatchCreateRequest request(Double lengthCm) {
        return CatchCreateRequest.of(1L, lengthCm, null, null, null, null, null);
    }

    private static LocalDateTime caughtAt(String value) {
        return CatchCreateRequest.of(1L, 30.0, null, value, null, null, null).caughtAt();
    }
}
