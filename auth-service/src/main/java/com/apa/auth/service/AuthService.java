package com.apa.auth.service;

import com.apa.auth.dto.LoginRequestDto;
import com.apa.auth.dto.LoginResponseDto;
import com.apa.auth.exception.UnauthorizedException;
import com.apa.common.security.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AuthService {

    /**
     * 스텁 로그인이 쓰는 고정 userId. {@code users} 테이블에 없는 값이다 —
     * 각 앱의 {@code user_id} 컬럼은 FK 가 아니라 값 컬럼이라 이걸로도 앱 개발이 굴러간다.
     *
     * <p>소셜 로그인을 붙일 때 <b>여기와 {@link #authenticate} 를 통째로 걷어낸다.</b>
     * 그때부터는 {@code users.id} 가 subject 로 들어간다.
     */
    private static final long STUB_USER_ID = 1L;

    private final JwtTokenProvider jwtTokenProvider;

    public LoginResponseDto login(LoginRequestDto request) {

        authenticate(request);

        // subject 는 username 이 아니라 userId 다 — 각 앱이 auth-service 를 되묻지 않고
        // 자기 스키마의 user_id 를 채울 수 있어야 한다.
        String accessToken = jwtTokenProvider.createToken(STUB_USER_ID, request.getUsername());

        return new LoginResponseDto(
                accessToken,
                "Bearer",
                jwtTokenProvider.getExpiration()
        );
    }

    /*
    사용자 인증
     */
    private void authenticate(LoginRequestDto request) {
        if (!"testuser".equals(request.getUsername())
                || !"hyun1234".equals(request.getPassword())) {
            throw new UnauthorizedException("Invalid credentials");
        }
    }
}
