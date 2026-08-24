package com.apa.fishing.domain;

import java.util.Locale;
import java.util.Optional;

/**
 * 신고 사유 (계약서 3-8).
 *
 * <p>자유 입력이 아니라 목록으로 받는 이유는 <b>나중에 세기 위해서다.</b> 운영 도구를 붙일 때
 * "이 글에 스팸 신고 5건" 은 정렬이 되지만 "이 글에 신고 5건(각각 다른 문장)" 은 다 읽어야 한다.
 *
 * <p>{@link PostCategory} 와 달리 모르는 값을 조용히 흘리지 않는다 — 목록 필터는 틀리면
 * 결과가 이상할 뿐이지만, 신고는 <b>사유가 신고 내용의 전부</b>라 엉뚱한 값이 저장되면
 * 그 신고는 처리할 수 없다.
 */
public enum ReportReason {
    /** 스팸 · 광고 */
    SPAM,
    /** 욕설 · 비방 */
    ABUSE,
    /** 음란물 · 부적절한 사진 */
    ADULT,
    /** 허위 조황 · 거짓 정보 — 조황 게시판이라 실제로 문제가 되는 축이다 */
    FALSE_INFO,
    /** 그 밖에. 이것만 설명을 함께 받는다 */
    OTHER;

    public static Optional<ReportReason> fromCode(String code) {
        if (code == null || code.isBlank()) {
            return Optional.empty();
        }
        try {
            return Optional.of(valueOf(code.trim().toUpperCase(Locale.ROOT)));
        } catch (IllegalArgumentException e) {
            return Optional.empty();
        }
    }
}
