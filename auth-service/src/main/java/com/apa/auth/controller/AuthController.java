package com.apa.auth.controller;

import com.apa.auth.dto.EmailLoginRequest;
import com.apa.auth.dto.EmailSignUpRequest;
import com.apa.auth.dto.LoginRequestDto;
import com.apa.auth.dto.LoginResponseDto;
import com.apa.auth.dto.RefreshRequest;
import com.apa.auth.dto.SocialLinkRequest;
import com.apa.auth.dto.SocialLoginRequest;
import com.apa.auth.dto.TokenResponse;
import com.apa.auth.service.AuthService;
import com.apa.auth.service.DevLoginService;
import com.apa.common.security.AuthenticatedUser;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final DevLoginService devLoginService;

    /** 자체 회원가입 (이메일 + 비밀번호). 가입과 동시에 토큰을 내려 바로 로그인 상태가 된다. */
    @PostMapping("/signup")
    public ResponseEntity<TokenResponse> signUp(@RequestBody EmailSignUpRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(authService.signUp(request));
    }

    /**
     * 회원 탈퇴 (계약서 3-9). 계정을 비활성하고 로그인 수단을 지운다.
     *
     * <p>⚠️ 앱은 <b>이걸 마지막에</b> 부른다. 먼저 각 앱 서비스에 자기 데이터를 지우라고
     * 요청해야 한다 — 여기가 먼저 돌면 토큰이 죽어서 그 요청들을 보낼 수 없다.
     */
    @DeleteMapping("/me")
    public ResponseEntity<Void> withdraw(@AuthenticationPrincipal AuthenticatedUser user) {
        authService.withdraw(user.userId());
        return ResponseEntity.noContent().build();
    }

    /** 자체 가입 계정 로그인. */
    @PostMapping("/login/email")
    public ResponseEntity<TokenResponse> loginWithEmail(@RequestBody EmailLoginRequest request) {
        return ResponseEntity.ok(authService.loginWithEmail(request));
    }

    /**
     * 소셜 로그인 (기획서 v2 5-3). 없으면 가입하고, 있으면 로그인한다.
     *
     * <p>같은 이메일로 자체 가입한 계정이 이미 있으면 <b>409 {@code LINK_REQUIRED}</b> 다.
     * 프론트는 비밀번호를 받아 {@code /auth/link/social} 로 다시 온다.
     */
    @PostMapping("/login")
    public ResponseEntity<TokenResponse> login(@RequestBody SocialLoginRequest request) {
        return ResponseEntity.ok(authService.login(request));
    }

    /**
     * 계정 연동 — 자체 가입 계정에 소셜을 붙이고 그대로 로그인시킨다.
     * {@code /auth/login} 이 낸 409 {@code LINK_REQUIRED} 에 대한 응답이다.
     *
     * <p>토큰 없이 부를 수 있다. 아직 로그인하지 않은 사람이 부르는 자리이고,
     * 비밀번호와 소셜 토큰 <b>둘 다</b>를 검증하므로 인증 자체가 여기서 일어난다.
     */
    @PostMapping("/link/social")
    public ResponseEntity<TokenResponse> linkSocial(@RequestBody SocialLinkRequest request) {
        return ResponseEntity.ok(authService.linkSocial(request));
    }

    /**
     * 액세스 토큰 재발급. 프론트 {@code api_client.dart} 가 401 을 받으면 자동으로 부르고
     * 원 요청을 한 번 재시도한다.
     */
    @PostMapping("/refresh")
    public ResponseEntity<TokenResponse> refresh(@RequestBody RefreshRequest request) {
        return ResponseEntity.ok(authService.refresh(request.refreshToken()));
    }

    /**
     * 로그아웃. 리프레시 토큰을 서버에서 버린다.
     *
     * <p>토큰 없이 부르면 401 이다 — 누구의 토큰을 지울지 알 수 없기 때문이다.
     * 프론트는 이 호출이 실패해도 로컬 토큰은 지워야 한다.
     */
    @PostMapping("/logout")
    public ResponseEntity<Void> logout(
            @AuthenticationPrincipal AuthenticatedUser user,
            @RequestParam(required = false) String appId
    ) {
        authService.logout(user.userId(), appId);
        return ResponseEntity.noContent().build();
    }

    /**
     * 개발용 고정 로그인. {@code auth.dev-login-enabled=true} 일 때만 동작한다.
     * 검증 스크립트({@code 낚시출조앱_6G검증.ps1})가 쓴다.
     */
    @PostMapping("/dev-login")
    public ResponseEntity<LoginResponseDto> devLogin(@RequestBody LoginRequestDto request) {
        return ResponseEntity.ok(devLoginService.login(request));
    }
}
