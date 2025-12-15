package com.apa.auth.service;

import com.apa.auth.dto.LoginRequestDto;
import com.apa.auth.dto.LoginResponseDto;
import com.apa.auth.exception.UnauthorizedException;
import com.apa.auth.security.jwt.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final JwtTokenProvider jwtTokenProvider;

    public LoginResponseDto login(LoginRequestDto request) {

        authenticate(request);

        String accessToken = jwtTokenProvider.createToken(
                request.getUsername()
        );

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
