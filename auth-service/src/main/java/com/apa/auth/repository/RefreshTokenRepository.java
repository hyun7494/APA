package com.apa.auth.repository;

import com.apa.auth.domain.RefreshToken;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.Optional;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    /** 로그아웃 — 그 기기뿐 아니라 해당 앱의 토큰을 전부 무효화한다. */
    void deleteByUserIdAndAppId(Long userId, String appId);

    /** 만료분 청소. 지우지 않으면 로그인할 때마다 한 줄씩 쌓이기만 한다. */
    int deleteByExpiresAtBefore(LocalDateTime at);
}
