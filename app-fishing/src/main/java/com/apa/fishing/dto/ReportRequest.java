package com.apa.fishing.dto;

import com.apa.fishing.domain.ReportReason;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/**
 * {@code POST /fishing/board/{id}/report} 요청.
 *
 * <p>{@code CatchCreateRequest} 와 같은 이유로 정규화를 여기서 한다 — 순수 함수라
 * 서블릿 없이 테스트된다.
 */
public record ReportRequest(ReportReason reason, String detail) {

    /** 컬럼이 VARCHAR(300) 다 (V12). */
    private static final int DETAIL_MAX = 300;

    public static ReportRequest of(String reason, String detail) {
        ReportReason parsed = ReportReason.fromCode(reason)
                .orElseThrow(() -> badRequest("신고 사유를 선택해 주세요"));

        String trimmed = detail == null || detail.isBlank() ? null : detail.trim();

        // `기타` 는 사유 이름만으로는 아무것도 알 수 없다. 설명이 없으면 그 신고는
        // 나중에 열어 봐도 처리할 수가 없으므로, 받아 두고 못 쓰느니 여기서 막는다.
        if (parsed == ReportReason.OTHER && trimmed == null) {
            throw badRequest("어떤 점이 문제인지 적어 주세요");
        }
        if (trimmed != null && trimmed.length() > DETAIL_MAX) {
            throw badRequest("신고 내용은 %d자까지 입력할 수 있습니다".formatted(DETAIL_MAX));
        }

        return new ReportRequest(parsed, trimmed);
    }

    private static ResponseStatusException badRequest(String message) {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, message);
    }
}
