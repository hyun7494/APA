package com.apa.auth.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 인증 동작 설정.
 *
 * @param refreshExpirationSeconds 리프레시 토큰 수명. 기본 30일 — 이보다 짧으면 한 달에 한 번씩
 *                                 재로그인을 요구하게 되고, 길면 유출 시 노출 창이 길어진다
 * @param devLoginEnabled          {@code POST /auth/dev-login} 을 열지 여부.
 *                                 <b>운영에서는 반드시 false 여야 한다</b> — 켜져 있으면
 *                                 아이디·비밀번호를 아는 누구나 {@code userId=1} 로 들어온다
 */
@ConfigurationProperties(prefix = "auth")
public record AuthProperties(long refreshExpirationSeconds, boolean devLoginEnabled) {

    /** 이 auth-service 를 쓰는 유일한 클라이언트. 프론트가 appId 를 빠뜨렸을 때의 기본값이다. */
    public static final String DEFAULT_APP_ID = "FISHING";

    private static final long THIRTY_DAYS = 30L * 24 * 60 * 60;

    public AuthProperties {
        if (refreshExpirationSeconds <= 0) refreshExpirationSeconds = THIRTY_DAYS;
    }
}
