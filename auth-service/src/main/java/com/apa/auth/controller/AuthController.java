package com.apa.auth.controller;

import com.apa.auth.dto.LoginRequestDto;
import com.apa.auth.dto.LoginResponseDto;
import com.apa.auth.dto.RefreshRequest;
import com.apa.auth.dto.SocialLoginRequest;
import com.apa.auth.dto.TokenResponse;
import com.apa.auth.service.AuthService;
import com.apa.auth.service.DevLoginService;
import com.apa.common.security.AuthenticatedUser;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final DevLoginService devLoginService;

    /** 소셜 로그인 (기획서 v2 5-3). 없으면 가입하고, 있으면 로그인한다. */
    @PostMapping("/login")
    public ResponseEntity<TokenResponse> login(@RequestBody SocialLoginRequest request) {
        return ResponseEntity.ok(authService.login(request));
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
