package com.apa.auth.service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HexFormat;

/**
 * 리프레시 토큰 생성·해시.
 *
 * <p>비밀번호가 아니라 <b>고엔트로피 랜덤</b>이라 bcrypt 같은 느린 해시를 쓰지 않는다.
 * 느린 해시의 목적은 사전 공격을 늦추는 것인데, 256비트 랜덤에는 추측할 사전이 없다.
 * 대신 조회가 인덱스 한 번으로 끝난다 — bcrypt 였다면 후보 행을 전부 꺼내 비교해야 한다.
 */
public final class TokenHash {

    private static final SecureRandom RANDOM = new SecureRandom();

    /** 256비트. URL-safe base64 로 43자가 된다. */
    private static final int TOKEN_BYTES = 32;

    private TokenHash() {
    }

    public static String newToken() {
        byte[] bytes = new byte[TOKEN_BYTES];
        RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    /** 64자 hex. {@code refresh_tokens.token_hash} 에 그대로 들어간다. */
    public static String hash(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            // SHA-256 은 JDK 표준이라 실제로 일어나지 않는다.
            throw new IllegalStateException("SHA-256 을 쓸 수 없습니다", e);
        }
    }
}
