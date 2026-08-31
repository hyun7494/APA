package com.apa.auth.repository;

import com.apa.auth.domain.RefreshToken;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    /** 로그아웃 — 그 기기뿐 아니라 해당 앱의 토큰을 전부 무효화한다. */
    void deleteByUserIdAndAppId(Long userId, String appId);

    /** 탈퇴 — 모든 앱의 갱신 토큰을 끊는다. 남겨 두면 탈퇴 뒤에도 토큰이 되살아난다. */
    void deleteByUserId(Long userId);
}
