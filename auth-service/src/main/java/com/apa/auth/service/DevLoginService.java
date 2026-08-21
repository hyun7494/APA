package com.apa.auth.service;

import com.apa.auth.config.AuthProperties;
import com.apa.auth.dto.LoginRequestDto;
import com.apa.auth.dto.LoginResponseDto;
import com.apa.auth.exception.UnauthorizedException;
import com.apa.common.security.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * 개발용 고정 로그인. <b>소셜 로그인이 붙기 전의 스텁을 여기로 옮겨 둔 것이다.</b>
 *
 * <p>없애지 않고 남긴 이유는 하나다 — {@code 낚시출조앱_6G검증.ps1} 이 이 계정으로 토큰을 받아
 * 조과·도감·사진 84개 항목을 두드린다. 실기기 소셜 로그인 없이 서버만 검증할 수단이 사라지면
 * 회귀를 잡을 방법이 없어진다.
 *
 * <p><b>대신 기본값은 꺼짐이고</b>({@code auth.dev-login-enabled}), 경로도 {@code /auth/login}
 * 이 아니라 {@code /auth/dev-login} 이다. 실서비스 경로와 섞이지 않는다.
 *
 * <p>발급하는 {@code userId=1} 은 {@code users} 테이블에 없는 값이다. 각 앱의 {@code user_id}
 * 는 FK 가 아니라 값 컬럼이라 그래도 동작한다.
 */
@Service
@RequiredArgsConstructor
public class DevLoginService {

    private static final long STUB_USER_ID = 1L;
    private static final String STUB_USERNAME = "testuser";
    private static final String STUB_PASSWORD = "hyun1234";

    private final JwtTokenProvider jwtTokenProvider;
    private final AuthProperties authProperties;

    public LoginResponseDto login(LoginRequestDto request) {
        if (!authProperties.devLoginEnabled()) {
            throw new UnauthorizedException("개발용 로그인이 꺼져 있습니다");
        }
        if (!STUB_USERNAME.equals(request.getUsername())
                || !STUB_PASSWORD.equals(request.getPassword())) {
            throw new UnauthorizedException("Invalid credentials");
        }

        return new LoginResponseDto(
                jwtTokenProvider.createToken(STUB_USER_ID, request.getUsername()),
                "Bearer",
                jwtTokenProvider.getExpiration());
    }
}
