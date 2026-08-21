package com.apa.auth.social;

/**
 * 소셜 토큰을 신뢰할 수 없을 때.
 *
 * <p>제공자가 응답을 안 주는 것(장애)과 토큰이 가짜인 것을 {@link #providerUnavailable} 로
 * 가른다. 둘을 같이 401 로 내면 카카오 장애 때 전 사용자에게 "로그인 정보가 잘못됐습니다" 가
 * 뜨고, 사용자는 있지도 않은 자기 잘못을 찾게 된다.
 */
public class SocialVerificationException extends RuntimeException {

    private final boolean providerUnavailable;

    public SocialVerificationException(String message) {
        this(message, false, null);
    }

    public SocialVerificationException(String message, boolean providerUnavailable, Throwable cause) {
        super(message, cause);
        this.providerUnavailable = providerUnavailable;
    }

    public static SocialVerificationException unavailable(String message, Throwable cause) {
        return new SocialVerificationException(message, true, cause);
    }

    public boolean isProviderUnavailable() {
        return providerUnavailable;
    }
}
