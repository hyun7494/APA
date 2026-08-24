package com.apa.fishing.dto;

import com.apa.fishing.domain.ReportReason;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 신고 요청 정규화 (계약서 3-8).
 *
 * <p>여기서 막아야 할 건 <b>나중에 열어 봐도 처리할 수 없는 신고</b>다 — 사유를 모르거나,
 * `기타` 인데 설명이 없는 것. 신고 내용이 사실인지는 서버가 판단할 수 없고 하지도 않는다.
 */
class ReportRequestTest {

    @Test
    @DisplayName("사유 코드를 대소문자 상관없이 받는다")
    void parsesReason() {
        assertThat(ReportRequest.of("SPAM", null).reason()).isEqualTo(ReportReason.SPAM);
        assertThat(ReportRequest.of("spam", null).reason()).isEqualTo(ReportReason.SPAM);
        assertThat(ReportRequest.of(" Abuse ", null).reason()).isEqualTo(ReportReason.ABUSE);
    }

    @Test
    @DisplayName("★ 모르는 사유는 400 — PostCategory 와 달리 조용히 흘리지 않는다")
    void rejectsUnknownReason() {
        // 목록 필터는 틀리면 결과가 이상할 뿐이지만, 신고는 사유가 내용의 전부라
        // 엉뚱한 값이 저장되면 그 신고를 처리할 수 없다.
        assertThatThrownBy(() -> ReportRequest.of("NOPE", null))
                .isInstanceOf(ResponseStatusException.class);
        assertThatThrownBy(() -> ReportRequest.of(null, null))
                .isInstanceOf(ResponseStatusException.class);
        assertThatThrownBy(() -> ReportRequest.of("  ", null))
                .isInstanceOf(ResponseStatusException.class);
    }

    @Test
    @DisplayName("★ `기타` 는 설명이 있어야 한다 — 사유 이름만으로는 아무것도 알 수 없다")
    void otherNeedsDetail() {
        assertThatThrownBy(() -> ReportRequest.of("OTHER", null))
                .isInstanceOf(ResponseStatusException.class);
        assertThatThrownBy(() -> ReportRequest.of("OTHER", "   "))
                .isInstanceOf(ResponseStatusException.class);

        assertThat(ReportRequest.of("OTHER", "같은 사진을 계속 올려요").detail())
                .isEqualTo("같은 사진을 계속 올려요");
    }

    @Test
    @DisplayName("나머지 사유는 설명이 선택이다")
    void detailIsOptionalOtherwise() {
        assertThat(ReportRequest.of("SPAM", null).detail()).isNull();
        // 빈 문자열을 넣어 두면 "없음"과 "비워 둠"이 섞인다.
        assertThat(ReportRequest.of("SPAM", "  ").detail()).isNull();
        assertThat(ReportRequest.of("SPAM", " 광고글이에요 ").detail()).isEqualTo("광고글이에요");
    }

    @Test
    @DisplayName("300자를 넘으면 400 — 자르지 않고 거절한다 (INSERT 가 터지기 전에)")
    void rejectsLongDetail() {
        assertThat(ReportRequest.of("SPAM", "가".repeat(300)).detail()).hasSize(300);
        assertThatThrownBy(() -> ReportRequest.of("SPAM", "가".repeat(301)))
                .isInstanceOf(ResponseStatusException.class);
    }
}
