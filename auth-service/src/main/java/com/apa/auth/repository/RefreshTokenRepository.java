package com.apa.auth.repository;

import com.apa.auth.domain.RefreshToken;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    /** 로그아웃 — 그 기기뿐 아니라 해당 앱의 토큰을 전부 무효화한다. */
    void deleteByUserIdAndAppId(Long userId, String appId);
}
