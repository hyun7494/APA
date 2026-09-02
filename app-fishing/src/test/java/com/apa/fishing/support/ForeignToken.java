package com.apa.fishing.support;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;

import java.nio.charset.StandardCharsets;
import java.util.Date;

/**
 * <b>남의 서버가 발급한 것과 같은 모양</b>의 토큰을 만든다 — 서명만 다르다.
 *
 * <p>{@code JwtTokenProvider} 를 쓰지 않고 여기서 다시 만드는 이유: 그쪽은 우리 비밀값이
 * 박힌 빈이라 다른 키로 서명할 수가 없다. 모양이 똑같아야 검사에 뜻이 생기므로
 * (subject·claim·만료) 발급 코드를 그대로 따라 적었다.
 *
 * <p>⚠️ {@code JwtTokenProvider.createToken} 이 바뀌면 여기도 따라 고칠 것. 안 고치면
 * 이 토큰이 <b>서명이 아니라 모양 때문에</b> 거절돼서, 검사가 통과하는데 정작 아무것도
 * 확인하지 않는 상태가 된다.
 */
public final class ForeignToken {

    private ForeignToken() {}

    public static String signedWith(String secret, long userId, String nickname) {
        Date now = new Date();
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .claim("nickname", nickname)
                .issuedAt(now)
                .expiration(new Date(now.getTime() + 3_600_000))
                .signWith(Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8)))
                .compact();
    }
}
