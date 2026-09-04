package com.apa.auth.service;

import com.apa.common.time.Kst;
import com.apa.auth.config.AuthProperties;
import com.apa.auth.domain.RefreshToken;
import com.apa.auth.domain.SocialType;
import com.apa.auth.domain.User;
import com.apa.auth.domain.UserAppLink;
import com.apa.auth.domain.UserSocialAccount;
import com.apa.auth.dto.EmailLoginRequest;
import com.apa.auth.dto.EmailSignUpRequest;
import com.apa.auth.dto.SocialLinkRequest;
import com.apa.auth.dto.SocialLoginRequest;
import com.apa.auth.dto.TokenResponse;
import com.apa.auth.exception.ConflictException;
import com.apa.auth.exception.SocialLinkRequiredException;
import com.apa.auth.exception.UnauthorizedException;
import com.apa.auth.repository.RefreshTokenRepository;
import com.apa.auth.repository.UserAppLinkRepository;
import com.apa.auth.repository.UserRepository;
import com.apa.auth.repository.UserSocialAccountRepository;
import com.apa.auth.social.SocialProfile;
import com.apa.auth.social.SocialVerifiers;
import com.apa.common.security.JwtTokenProvider;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * 로그인 세 갈래와 토큰 재발급.
 *
 * <ul>
 *   <li>자체 가입 — {@link #signUp}, {@link #loginWithEmail}</li>
 *   <li>소셜 — {@link #login}</li>
 *   <li>계정 연동 — {@link #linkSocial}. 위 둘이 같은 사람일 때 하나로 합친다</li>
 * </ul>
 *
 * <p>스텁 로그인({@code testuser}/{@code hyun1234})은 {@link DevLoginService} 로 옮겼다.
 * 이제 여기에는 실제 계정만 흐른다.
 */
@Service
public class AuthService {

    private final UserRepository userRepository;
    private final UserSocialAccountRepository socialAccountRepository;
    private final UserAppLinkRepository userAppLinkRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final SocialVerifiers socialVerifiers;
    private final JwtTokenProvider jwtTokenProvider;
    private final AuthProperties authProperties;
    private final PasswordEncoder passwordEncoder;
    private final ConsentRecorder consentRecorder;

    /**
     * 없는 계정에 대고 대조할 가짜 해시.
     *
     * <p>계정이 없을 때 BCrypt 를 건너뛰면 응답이 눈에 띄게 빨라진다. 그 차이만으로
     * <b>어떤 이메일이 가입돼 있는지 훑어볼 수 있다</b> — 실패 문구를 똑같이 맞춰 둔 의미가
     * 없어진다. 매번 새 난수로 만들어 아무도 이 값을 맞힐 수 없게 한다.
     */
    private final String absentUserHash;

    public AuthService(UserRepository userRepository,
                       UserSocialAccountRepository socialAccountRepository,
                       UserAppLinkRepository userAppLinkRepository,
                       RefreshTokenRepository refreshTokenRepository,
                       SocialVerifiers socialVerifiers,
                       JwtTokenProvider jwtTokenProvider,
                       AuthProperties authProperties,
                       PasswordEncoder passwordEncoder,
                       ConsentRecorder consentRecorder) {
        this.userRepository = userRepository;
        this.socialAccountRepository = socialAccountRepository;
        this.userAppLinkRepository = userAppLinkRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.socialVerifiers = socialVerifiers;
        this.jwtTokenProvider = jwtTokenProvider;
        this.authProperties = authProperties;
        this.passwordEncoder = passwordEncoder;
        this.consentRecorder = consentRecorder;
        this.absentUserHash = passwordEncoder.encode(UUID.randomUUID().toString());
    }

    // ───────────────────────────────────────────────────────────── 탈퇴

    /**
     * 회원 탈퇴 — 계정을 비활성하고 로그인 수단을 지운다 (이용약관 12조).
     *
     * <p>★ <b>행을 지우지 않는다.</b> 조과·게시글이 {@code user_id} 를 참조하고, 무엇보다
     * 행이 사라지면 {@code uq_users_nickname_lower} 가 풀려 <b>떠난 사람의 닉네임을 남이
     * 가져갈 수 있다</b> — 게시글에 박힌 옛 이름이 다른 사람 것처럼 보이게 된다.
     *
     * <p>★ <b>다른 서비스의 데이터는 여기서 손대지 않는다.</b> 앱이 먼저
     * {@code DELETE /fishing/me} 를 불러 조과·사진을 지우고 글쓴이를 가린 뒤에 이걸 부른다.
     * 순서를 뒤집으면 토큰이 죽어 그 요청을 보낼 수 없다.
     *
     * <p>이미 탈퇴한 계정에 다시 불러도 조용히 통과한다 — 앱이 중간에 실패해 다시 눌러도
     * 안전해야 한다.
     */
    @Transactional
    public void withdraw(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new UnauthorizedException("계정을 찾을 수 없습니다"));

        if (user.isActive()) {
            user.withdraw(Kst.now());
        }
        // 토큰·소셜 연결은 상태와 무관하게 확실히 끊는다.
        refreshTokenRepository.deleteByUserId(userId);
        socialAccountRepository.deleteByUserId(userId);
    }

    // ───────────────────────────────────────────────────────────── 자체 가입

    /** 이메일·비밀번호로 가입하고 곧바로 로그인시킨다. 가입 직후 다시 로그인을 시키면 이탈한다. */
    @Transactional
    public TokenResponse signUp(EmailSignUpRequest request) {
        String email = EmailAddress.require(request.email());
        // 이메일을 함께 넘긴다 — 아이디와 같은 비밀번호를 막으려면 필요하다.
        String rawPassword = PasswordPolicy.require(request.password(), email);
        String appId = normalizeAppId(request.appId());

        // ★ 적어 낸 이름과 우리가 지어 준 이름을 **다르게** 다룬다.
        //   적어 낸 것이 겹치면 되묻고(409), 이메일에서 뽑아 준 것이 겹치면 뒤에 숫자를
        //   붙인다 — 후자는 사용자가 고른 이름이 아니라서 물어볼 것이 없다.
        boolean chosen = request.nickname() != null && !request.nickname().isBlank();
        String nickname = chosen
                ? Nickname.require(request.nickname())
                : Nickname.withSuffix(EmailAddress.toNickname(email), 0, this::nicknameTaken);

        // 미리 조회해 봐야 동시 요청은 못 막는다. UNIQUE 제약이 진짜 방어선이고,
        // 이 조회는 대부분의 경우에 더 친절한 메시지를 주기 위한 것이다.
        if (userRepository.findByEmail(email).isPresent()) {
            throw new ConflictException("이미 가입된 이메일입니다");
        }
        if (chosen && nicknameTaken(nickname)) {
            throw new ConflictException("이미 사용 중인 닉네임입니다");
        }

        User user;
        try {
            user = userRepository.saveAndFlush(
                    User.registerWithEmail(email, passwordEncoder.encode(rawPassword), nickname));
        } catch (DataIntegrityViolationException e) {
            // ⚠️ 이메일과 닉네임 **둘 다** 여기로 온다. 어느 쪽이 걸렸는지 예외만으로는
            //    알 수 없어서 다시 물어본다 — 틀린 이유를 대면 사용자는 엉뚱한 칸을 고친다.
            throw new ConflictException(userRepository.findByEmail(email).isPresent()
                    ? "이미 가입된 이메일입니다"
                    : "이미 사용 중인 닉네임입니다");
        }

        // ⚠️ 동의는 **계정을 만든 뒤, 같은 트랜잭션 안에서** 남긴다. 먼저 검사하려 해도
        //    user_id 가 없어 행을 못 만들고, 트랜잭션 밖으로 빼면 동의 없는 계정이 남는다.
        consentRecorder.recordForSignUp(user.getId(), request.consents());

        linkApp(user.getId(), appId);
        return issueTokens(user, appId);
    }

    /**
     * 이메일 로그인.
     *
     * <p><b>없는 계정과 틀린 비밀번호를 구분해 알려 주지 않는다.</b> 둘이 갈리면
     * 그것만으로 어떤 주소가 가입돼 있는지 훑어볼 수 있다.
     */
    @Transactional
    public TokenResponse loginWithEmail(EmailLoginRequest request) {
        String email = EmailAddress.normalize(request.email());
        String appId = normalizeAppId(request.appId());
        String rawPassword = request.password() == null ? "" : request.password();

        User user = email == null ? null : userRepository.findByEmail(email).orElse(null);

        if (user == null || !user.hasPassword()) {
            passwordEncoder.matches(rawPassword, absentUserHash);  // 응답 시간을 맞춘다
            throw new UnauthorizedException(loginFailureMessage(user));
        }
        if (!passwordEncoder.matches(rawPassword, user.getPasswordHash())) {
            throw new UnauthorizedException("이메일 또는 비밀번호가 올바르지 않습니다");
        }
        if (!user.isActive()) {
            throw new UnauthorizedException("탈퇴한 계정입니다");
        }

        linkApp(user.getId(), appId);
        return issueTokens(user, appId);
    }

    /**
     * 소셜로만 만든 계정에 이메일 로그인을 시도한 경우는 안내가 달라야 한다.
     *
     * <p>그 계정의 존재는 사용자가 이미 아는 사실이다 — 자기가 그 주소로 가입했으니까.
     * 여기서까지 "이메일 또는 비밀번호가 올바르지 않습니다"로 뭉개면
     * <b>자기 계정을 눈앞에 두고 들어갈 방법을 못 찾는다.</b>
     */
    private String loginFailureMessage(User user) {
        if (user != null && !user.hasPassword()) {
            return "소셜 로그인으로 가입한 계정입니다. 카카오 또는 Google 로 로그인해 주세요";
        }
        return "이메일 또는 비밀번호가 올바르지 않습니다";
    }

    // ───────────────────────────────────────────────────────────────── 소셜

    /**
     * 소셜 로그인 (기획서 v2 5-3). 없으면 가입하고, 있으면 로그인한다.
     *
     * @throws SocialLinkRequiredException 같은 이메일의 자체 가입 계정이 이미 있을 때.
     *         프론트가 비밀번호를 받아 {@link #linkSocial} 로 다시 온다
     */
    @Transactional
    public TokenResponse login(SocialLoginRequest request) {
        String appId = normalizeAppId(request.appId());
        SocialProfile profile = verifySocialToken(request.provider(), request.token());

        User user = resolveSocialUser(profile);
        if (!user.isActive()) {
            throw new UnauthorizedException("탈퇴한 계정입니다");
        }
        // ⚠️ 닉네임까지 매번 덮어쓰지 않는다. 제공자 쪽 이름이 **다른 사람이 이미 쓰는
        //    이름**이면 UNIQUE 에 걸려 로그인 자체가 죽고, 우리 앱에서 바꾼 이름도
        //    로그인할 때마다 되돌아간다. 겹치지 않을 때만 따라간다.
        String incoming = Nickname.normalize(profile.nickname());
        boolean keepNickname = incoming == null
                || incoming.equalsIgnoreCase(user.getNickname())
                || nicknameTaken(incoming);
        user.syncProfile(keepNickname ? user.getNickname() : incoming, profile.profileUrl());

        linkApp(user.getId(), appId);
        return issueTokens(user, appId);
    }

    /**
     * 계정 연동 — 자체 가입 계정에 소셜을 붙이고 그대로 로그인시킨다.
     *
     * <p>비밀번호를 다시 받는 이유는 {@link SocialLinkRequiredException} 에 적어 두었다.
     */
    @Transactional
    public TokenResponse linkSocial(SocialLinkRequest request) {
        String appId = normalizeAppId(request.appId());
        SocialProfile profile = verifySocialToken(request.provider(), request.token());

        if (!profile.hasVerifiedEmail()) {
            // 올 수 없는 조합이다 — 확인된 주소가 없으면 애초에 연동을 요구하지 않는다.
            throw new UnauthorizedException("연동할 수 있는 이메일을 제공자에게서 받지 못했습니다");
        }

        User user = userRepository.findByEmail(profile.email()).orElse(null);
        String rawPassword = request.password() == null ? "" : request.password();

        if (user == null || !user.hasPassword()) {
            passwordEncoder.matches(rawPassword, absentUserHash);
            throw new UnauthorizedException("비밀번호가 올바르지 않습니다");
        }
        if (!passwordEncoder.matches(rawPassword, user.getPasswordHash())) {
            throw new UnauthorizedException("비밀번호가 올바르지 않습니다");
        }
        if (!user.isActive()) {
            throw new UnauthorizedException("탈퇴한 계정입니다");
        }

        attachSocialAccount(user, profile);
        // 닉네임은 덮지 않는다. 자체 가입 때 직접 정한 이름이 소셜 닉네임보다 우선이다.
        user.syncProfile(null, profile.profileUrl());

        linkApp(user.getId(), appId);
        return issueTokens(user, appId);
    }

    private SocialProfile verifySocialToken(String rawProvider, String token) {
        SocialType provider = SocialType.from(rawProvider)
                .orElseThrow(() -> new UnauthorizedException(
                        "지원하지 않는 로그인 방식입니다: " + rawProvider));

        if (token == null || token.isBlank()) {
            throw new UnauthorizedException("로그인 토큰이 없습니다");
        }

        // 신뢰의 출발점. 이 호출이 성공해야만 아래 모든 것이 의미를 갖는다.
        return socialVerifiers.get(provider).verify(token);
    }

    /**
     * 소셜 신원 → 계정. 세 갈래다.
     *
     * <ol>
     *   <li>이미 붙어 있는 신원 → 그 계정으로 로그인</li>
     *   <li>처음 보는 신원인데 <b>확인된 이메일</b>의 계정이 이미 있음 → 새로 만들지 않는다.
     *       비밀번호가 있는 계정이면 연동 확인을 요구하고, 없으면(= 다른 소셜로만 만든 계정)
     *       양쪽 제공자가 같은 주소의 소유를 확인해 준 셈이므로 그대로 잇는다</li>
     *   <li>그 외 → 신규 가입</li>
     * </ol>
     */
    private User resolveSocialUser(SocialProfile profile) {
        UserSocialAccount linked = socialAccountRepository
                .findBySocialTypeAndSocialId(profile.socialType(), profile.socialId())
                .orElse(null);

        if (linked != null) {
            return userRepository.findById(linked.getUserId())
                    .orElseThrow(() -> new UnauthorizedException("계정을 찾을 수 없습니다"));
        }

        if (profile.hasVerifiedEmail()) {
            User owner = userRepository.findByEmail(profile.email()).orElse(null);
            if (owner != null) {
                if (!owner.isActive()) {
                    throw new UnauthorizedException("탈퇴한 계정입니다");
                }
                if (owner.hasPassword()) {
                    throw new SocialLinkRequiredException(owner.getEmail(), profile.socialType());
                }
                attachSocialAccount(owner, profile);
                return owner;
            }
        }

        return registerFromSocial(profile);
    }

    /**
     * 신규 소셜 가입.
     *
     * <p>같은 사람이 두 기기에서 동시에 첫 로그인을 하면 두 요청이 모두 "없음"을 보고 INSERT 를
     * 시도한다. {@code UNIQUE(social_type, social_id)} 가 한쪽을 튕겨내므로, 그때는 상대가 만든
     * 행을 <b>다시 읽어</b> 쓴다. 이 처리를 빼면 첫 로그인이 간헐적으로 500 이 된다.
     */
    private User registerFromSocial(SocialProfile profile) {
        try {
            // 확인되지 않은 주소는 users.email 에 넣지 않는다. 넣어 두면 그 주소의 진짜
            // 주인이 나중에 자체 가입을 하려 할 때 "이미 가입된 이메일"로 막힌다.
            User user = userRepository.saveAndFlush(User.registerFromSocial(
                    defaultNickname(profile),
                    profile.profileUrl(),
                    profile.hasVerifiedEmail() ? profile.email() : null));

            socialAccountRepository.saveAndFlush(UserSocialAccount.link(
                    user.getId(), profile.socialType(), profile.socialId(), profile.email()));
            return user;
        } catch (DataIntegrityViolationException e) {
            return socialAccountRepository
                    .findBySocialTypeAndSocialId(profile.socialType(), profile.socialId())
                    .flatMap(account -> userRepository.findById(account.getUserId()))
                    .orElseThrow(() -> e);
        }
    }

    /** 기존 계정에 소셜 신원을 붙인다. 이미 같은 신원이 붙어 있으면 아무것도 하지 않는다. */
    private void attachSocialAccount(User user, SocialProfile profile) {
        UserSocialAccount sameProvider = socialAccountRepository
                .findByUserIdAndSocialType(user.getId(), profile.socialType())
                .orElse(null);

        if (sameProvider != null) {
            if (!sameProvider.getSocialId().equals(profile.socialId())) {
                // 한 계정에 같은 제공자를 두 번 붙이면 어느 쪽으로 들어왔는지에 따라
                // 프로필이 오락가락한다. DB 도 UNIQUE(user_id, social_type) 로 막는다.
                throw new ConflictException("이 계정에는 이미 다른 "
                        + providerName(profile.socialType()) + " 계정이 연결되어 있습니다");
            }
            return;  // 같은 신원이 이미 붙어 있다
        }

        try {
            socialAccountRepository.saveAndFlush(UserSocialAccount.link(
                    user.getId(), profile.socialType(), profile.socialId(), profile.email()));
        } catch (DataIntegrityViolationException e) {
            // 같은 순간 다른 요청이 먼저 붙였다. 결과가 같으면 실패시킬 이유가 없다.
            UserSocialAccount winner = socialAccountRepository
                    .findBySocialTypeAndSocialId(profile.socialType(), profile.socialId())
                    .orElseThrow(() -> e);
            if (!winner.getUserId().equals(user.getId())) {
                throw new ConflictException("이미 다른 계정에 연결된 소셜 계정입니다");
            }
        }

    }

    private String providerName(SocialType type) {
        return type == SocialType.KAKAO ? "카카오" : "Google";
    }

    // ───────────────────────────────────────────────────────────────── 토큰

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
        if (stored.isExpired(Kst.now())) {
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
     * 닉네임 동의를 거부한 사용자에게 줄 이름.
     *
     * <p>비워 두면 컬럼이 NOT NULL 이라 가입 자체가 실패한다. 소셜 ID 를 그대로 쓰면 제공자
     * 식별자가 화면에 노출되므로 뒤 4자리만 붙인다.
     */
    private String defaultNickname(SocialProfile profile) {
        String fromProvider = Nickname.normalize(profile.nickname());
        if (fromProvider != null) {
            // 제공자가 준 이름도 남이 쓰고 있을 수 있다. 소셜은 물어볼 화면이 없어서
            // (첫 로그인이 곧 가입이다) 되묻는 대신 숫자를 붙인다.
            return Nickname.withSuffix(fromProvider, 0, this::nicknameTaken);
        }
        String id = profile.socialId();
        String suffix = id.length() <= 4 ? id : id.substring(id.length() - 4);
        return Nickname.withSuffix("낚시꾼" + suffix, 0, this::nicknameTaken);
    }

    /** 대소문자를 가리지 않는다 — UNIQUE 인덱스가 `lower(nickname)` 위에 있다. */
    private boolean nicknameTaken(String nickname) {
        return userRepository.existsByNicknameIgnoreCase(nickname);
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
                Kst.now().plusSeconds(authProperties.refreshExpirationSeconds())));

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
}
