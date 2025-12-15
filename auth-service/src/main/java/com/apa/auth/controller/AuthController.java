package com.apa.auth.controller;

import com.apa.auth.dto.LoginRequestDto;
import com.apa.auth.dto.LoginResponseDto;
import com.apa.auth.service.AuthService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/login")
    public ResponseEntity<LoginResponseDto> login(
            @RequestBody LoginRequestDto request
    ) {
        LoginResponseDto response = authService.login(request);
        return ResponseEntity.ok(response);
    }
}
