package com.apa.auth.dto;

import com.apa.auth.domain.User;

/**
 * 로그인·재발급 공통 응답.
 *
 * <p>{@code refreshToken} 을 매번 함께 내려준다 — 재발급 때 회전시키기 때문이다.
 * 프론트는 {@code accessToken}/{@code refreshToken} 두 필드만 보고 저장한다.
 *
 * @param expiresIn 액세스 토큰 만료(초). 프론트가 선제 갱신을 하고 싶을 때 쓴다
 */
public record TokenResponse(
        String accessToken,
        String refreshToken,
        String tokenType,
        long expiresIn,
        UserSummary user
) {

    public static TokenResponse of(String accessToken, String refreshToken, long expiresIn, User user) {
        return new TokenResponse(
                accessToken,
                refreshToken,
                "Bearer",
                expiresIn,
                UserSummary.from(user));
    }

    /**
     * 로그인 직후 화면에 뿌릴 최소 정보. 이걸 안 주면 프론트가 곧바로
     * {@code /fishing/me/profile} 을 한 번 더 부른다.
     */
    public record UserSummary(Long id, String nickname, String profileUrl) {

        static UserSummary from(User user) {
            return new UserSummary(user.getId(), user.getNickname(), user.getProfileUrl());
        }
    }
}
