package com.apa.auth.service;

import com.apa.auth.config.AuthProperties;
import com.apa.auth.domain.RefreshToken;
import com.apa.auth.domain.SocialType;
import com.apa.auth.domain.User;
import com.apa.auth.domain.UserAppLink;
import com.apa.auth.dto.SocialLoginRequest;
import com.apa.auth.dto.TokenResponse;
import com.apa.auth.exception.UnauthorizedException;
import com.apa.auth.repository.RefreshTokenRepository;
import com.apa.auth.repository.UserAppLinkRepository;
import com.apa.auth.repository.UserRepository;
import com.apa.auth.social.SocialProfile;
import com.apa.auth.social.SocialVerificationException;
import com.apa.auth.social.SocialVerifiers;
import com.apa.common.security.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

/**
 * 소셜 로그인과 토큰 재발급.
 *
 * <p>스텁 로그인({@code testuser}/{@code hyun1234})은 {@link DevLoginService} 로 옮겼다.
 * 이제 여기에는 실제 계정만 흐른다.
 */
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final UserAppLinkRepository userAppLinkRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final SocialVerifiers socialVerifiers;
    private final JwtTokenProvider jwtTokenProvider;
    private final AuthProperties authProperties;

    @Transactional
    public TokenResponse login(SocialLoginRequest request) {
        SocialType provider = SocialType.from(request.provider())
                .orElseThrow(() -> new UnauthorizedException(
                        "지원하지 않는 로그인 방식입니다: " + request.provider()));

        if (request.token() == null || request.token().isBlank()) {
            throw new UnauthorizedException("로그인 토큰이 없습니다");
        }

        String appId = normalizeAppId(request.appId());

        // 신뢰의 출발점. 이 호출이 성공해야만 아래 모든 것이 의미를 갖는다.
        SocialProfile profile = socialVerifiers.get(provider).verify(request.token());

        User user = findOrRegister(profile);
        if (!user.isActive()) {
            throw new UnauthorizedException("탈퇴한 계정입니다");
        }
        user.syncProfile(profile.nickname(), profile.profileUrl());

        linkApp(user.getId(), appId);

        return issueTokens(user, appId);
    }

    /**
     * 리프레시 토큰으로 재발급하고 <b>기존 토큰을 폐기한다(회전)</b>.
     *
     * <p>회전시키지 않으면 한 번 유출된 리프레시 토큰이 만료일까지 계속 유효하다. 회전하면
     * 공격자가 먼저 쓰는 순간 사용자의 토큰이 죽어서 <b>이상을 알아챌 수 있는 신호</b>가 된다.
     */
    @Transactional
    public TokenResponse refresh(String refreshToken) {
        if (refreshToken == null || refreshToken.isBlank()) {
            throw new UnauthorizedException("리프레시 토큰이 없습니다");
        }

        RefreshToken stored = refreshTokenRepository.findByTokenHash(TokenHash.hash(refreshToken))
                .orElseThrow(() -> new UnauthorizedException("다시 로그인해 주세요"));

        // 만료된 줄은 지우고 나간다. 남겨 두면 매번 같은 실패를 반복하며 쌓이기만 한다.
        if (stored.isExpired(LocalDateTime.now())) {
            refreshTokenRepository.delete(stored);
            throw new UnauthorizedException("로그인이 만료되었습니다. 다시 로그인해 주세요");
        }

        User user = userRepository.findById(stored.getUserId())
                .orElseThrow(() -> new UnauthorizedException("다시 로그인해 주세요"));
        if (!user.isActive()) {
            refreshTokenRepository.delete(stored);
            throw new UnauthorizedException("탈퇴한 계정입니다");
        }

        refreshTokenRepository.delete(stored);
        // 같은 트랜잭션에서 지우고 넣는다. UNIQUE(token_hash) 때문에 flush 순서가 중요한데,
        // 새 토큰은 랜덤이라 옛 해시와 충돌할 일이 없어 문제되지 않는다.
        return issueTokens(user, stored.getAppId());
    }

    /** 로그아웃 — 해당 앱의 리프레시 토큰을 전부 버린다. 액세스 토큰은 짧아서 곧 만료된다. */
    @Transactional
    public void logout(long userId, String appId) {
        refreshTokenRepository.deleteByUserIdAndAppId(userId, normalizeAppId(appId));
    }

    /**
     * 가입 또는 조회.
     *
     * <p>같은 사람이 두 기기에서 동시에 첫 로그인을 하면 두 요청이 모두 "없음"을 보고 INSERT 를
     * 시도한다. {@code UNIQUE(social_type, social_id)} 가 한쪽을 튕겨내므로, 그때는 상대가 만든
     * 행을 <b>다시 읽어</b> 쓴다. 이 처리를 빼면 첫 로그인이 간헐적으로 500 이 된다.
     */
    private User findOrRegister(SocialProfile profile) {
        return userRepository.findBySocialTypeAndSocialId(profile.socialType(), profile.socialId())
                .orElseGet(() -> {
                    try {
                        return userRepository.saveAndFlush(User.register(
                                profile.socialType(),
                                profile.socialId(),
                                defaultNickname(profile),
                                profile.profileUrl()));
                    } catch (DataIntegrityViolationException e) {
                        return userRepository
                                .findBySocialTypeAndSocialId(profile.socialType(), profile.socialId())
                                .orElseThrow(() -> e);
                    }
                });
    }

    /**
     * 닉네임 동의를 거부한 사용자에게 줄 이름.
     *
     * <p>비워 두면 컬럼이 NOT NULL 이라 가입 자체가 실패한다. 소셜 ID 를 그대로 쓰면 제공자
     * 식별자가 화면에 노출되므로 뒤 4자리만 붙인다.
     */
    private String defaultNickname(SocialProfile profile) {
        if (profile.nickname() != null && !profile.nickname().isBlank()) {
            return profile.nickname();
        }
        String id = profile.socialId();
        String suffix = id.length() <= 4 ? id : id.substring(id.length() - 4);
        return "낚시꾼" + suffix;
    }

    private void linkApp(Long userId, String appId) {
        userAppLinkRepository.findByUserIdAndAppId(userId, appId)
                .ifPresentOrElse(
                        UserAppLink::touch,
                        () -> userAppLinkRepository.save(UserAppLink.first(userId, appId)));
    }

    private TokenResponse issueTokens(User user, String appId) {
        String accessToken = jwtTokenProvider.createToken(user.getId(), user.getNickname());

        String refreshToken = TokenHash.newToken();
        refreshTokenRepository.save(RefreshToken.issue(
                user.getId(),
                appId,
                TokenHash.hash(refreshToken),
                LocalDateTime.now().plusSeconds(authProperties.refreshExpirationSeconds())));

        return TokenResponse.of(accessToken, refreshToken, jwtTokenProvider.getExpiration(), user);
    }

    /**
     * {@code app_id} 는 VARCHAR(20) 이다. 프론트가 안 보내면 낚시 앱으로 본다 —
     * 지금 이 auth-service 를 부르는 클라이언트가 그것뿐이다.
     */
    private String normalizeAppId(String appId) {
        if (appId == null || appId.isBlank()) return AuthProperties.DEFAULT_APP_ID;
        String trimmed = appId.trim().toUpperCase(java.util.Locale.ROOT);
        return trimmed.length() <= 20 ? trimmed : trimmed.substring(0, 20);
    }

    /** 제공자 장애는 401 이 아니라 503 이다 — 사용자가 고칠 수 있는 문제가 아니다. */
    public static boolean isProviderOutage(SocialVerificationException e) {
        return e.isProviderUnavailable();
    }
}
