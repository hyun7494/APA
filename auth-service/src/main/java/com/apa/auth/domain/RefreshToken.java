package com.apa.auth.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 리프레시 토큰. <b>원문을 저장하지 않는다</b> — SHA-256 해시만 넣는다.
 *
 * <p>DB 가 새더라도 저장된 값 그대로는 재발급에 못 쓴다. 액세스 토큰과 달리 수명이 길어서
 * (기본 30일) 유출 시 피해가 훨씬 크다.
 */
@Entity
@Table(name = "refresh_tokens")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class RefreshToken {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "token_hash", nullable = false, length = 255)
    private String tokenHash;

    @Column(name = "app_id", length = 20)
    private String appId;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    public static RefreshToken issue(Long userId, String appId, String tokenHash, LocalDateTime expiresAt) {
        RefreshToken token = new RefreshToken();
        token.userId = userId;
        token.appId = appId;
        token.tokenHash = tokenHash;
        token.expiresAt = expiresAt;
        token.createdAt = LocalDateTime.now();
        return token;
    }

    public boolean isExpired(LocalDateTime at) {
        return expiresAt.isBefore(at);
    }
}
