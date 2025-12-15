package com.apa.auth.controller;

import com.apa.auth.security.jwt.JwtTokenProvider;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class AuthTestController {

    private final JwtTokenProvider tokenProvider;

    public AuthTestController(JwtTokenProvider tokenProvider) {
        this.tokenProvider = tokenProvider;
    }

    @GetMapping("/auth/test-token")
    public String generateToken() {
        return tokenProvider.createToken("test-user");
    }
}
