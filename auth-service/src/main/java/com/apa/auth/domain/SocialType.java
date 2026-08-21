package com.apa.auth.domain;

import java.util.Arrays;
import java.util.Locale;
import java.util.Optional;

/**
 * 지원하는 소셜 제공자 (기획서 v2 실행순서 14).
 *
 * <p>DB {@code users.social_type} 은 VARCHAR(10) 이라 이름이 10자를 넘으면 안 된다.
 */
public enum SocialType {
    KAKAO,
    GOOGLE;

    /**
     * 프론트가 보낸 문자열을 관대하게 받는다. 대소문자를 가려 400 을 내면
     * "kakao" 와 "KAKAO" 중 무엇이 맞는지 계약서를 뒤지게 만들 뿐이다.
     */
    public static Optional<SocialType> from(String raw) {
        if (raw == null || raw.isBlank()) return Optional.empty();
        String normalized = raw.trim().toUpperCase(Locale.ROOT);
        return Arrays.stream(values())
                .filter(t -> t.name().equals(normalized))
                .findFirst();
    }
}
