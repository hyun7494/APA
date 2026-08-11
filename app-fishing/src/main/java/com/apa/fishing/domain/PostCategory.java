package com.apa.fishing.domain;

import java.util.Locale;
import java.util.Optional;

/**
 * 게시글 태그 (계약서 2-3). 프론트 탭이 이 대문자 코드로 매칭한다.
 */
public enum PostCategory {
    /** 조황 */
    CATCH,
    /** 자유 */
    FREE,
    /** 질문 */
    QUESTION;

    /**
     * 목록 필터용이라 {@link Optional} 을 준다 — 모르는 tag 를 FREE 로 떨어뜨리면
     * 오타 하나에 엉뚱한 탭 결과가 나가므로, 값이 없으면 필터를 걸지 않는 편이 낫다.
     */
    public static Optional<PostCategory> fromCode(String code) {
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
