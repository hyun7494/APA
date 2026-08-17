package com.apa.common.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.Optional;

/**
 * JWT 발급·검증. auth-service 에 있던 것을 common-lib 으로 옮겼다 —
 * <b>발급은 auth-service 만, 검증은 모든 앱이</b> 한다.
 *
 * <p>subject 는 username 이 아니라 <b>userId</b> 다. 멀티앱 구조에서 각 앱은 자기 스키마의
 * {@code user_id} 컬럼(예: {@code fishing_user_catches.user_id})을 채워야 하는데,
 * subject 가 username 이면 그 값을 얻으려고 매 요청마다 auth-service 를 불러야 한다.
 */
public class JwtTokenProvider {

    /** 닉네임까지 토큰에 실어 프로필 표시용 조회를 없앤다. 바뀌어도 다음 발급 때 갱신되면 충분한 값이다. */
    private static final String NICKNAME_CLAIM = "nickname";

    private final SecretKey key;
    private final long expirationMillis;

    public JwtTokenProvider(JwtProperties properties) {
        this.key = Keys.hmacShaKeyFor(properties.getSecret().getBytes(StandardCharsets.UTF_8));
        this.expirationMillis = properties.getExpiration();
    }

    public String createToken(long userId, String nickname) {
        Date now = new Date();
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .claim(NICKNAME_CLAIM, nickname)
                .issuedAt(now)
                .expiration(new Date(now.getTime() + expirationMillis))
                .signWith(key)
                .compact();
    }

    /** 프론트에 내려주는 만료(초). */
    public long getExpiration() {
        return expirationMillis / 1000;
    }

    /**
     * 검증 성공이면 사용자, 아니면 빈 값. <b>예외를 던지지 않는다</b> — 필터는 토큰이 없거나
     * 상한 요청도 그냥 비로그인으로 흘려보내야 하고(공개 API 가 대부분이다), 최종 401 판단은
     * 각 앱의 SecurityConfig 가 한다.
     *
     * <p>subject 가 숫자가 아닌 <b>구버전 토큰(subject=username)도 여기서 걸러진다</b> —
     * {@code NumberFormatException} 이 {@code IllegalArgumentException} 이라 같이 잡힌다.
     */
    public Optional<AuthenticatedUser> parse(String token) {
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(key)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();

            return Optional.of(new AuthenticatedUser(
                    Long.parseLong(claims.getSubject()),
                    claims.get(NICKNAME_CLAIM, String.class)));
        } catch (JwtException | IllegalArgumentException e) {
            return Optional.empty();
        }
    }
}
