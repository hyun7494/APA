package com.apa.fishing.controller;

import com.apa.common.security.AuthenticatedUser;
import com.apa.fishing.dto.ProfileResponse;
import com.apa.fishing.service.ProfileService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 마이페이지 (계약서 3-7).
 *
 * <p><b>인증 필수다.</b> {@code /fishing/me/**} 를 SecurityConfig 가 막고 있어 비로그인은 401 을
 * 받고, 프론트는 그 401 을 오류가 아니라 "로그인 안 됨"으로 삼켜 로그인 안내를 띄운다.
 * 401 이 아닌 응답(404 등)은 프론트가 그대로 오류 화면으로 올린다.
 */
@RestController
@RequestMapping("/fishing/me/profile")
@RequiredArgsConstructor
public class ProfileController {

    private final ProfileService profileService;

    @GetMapping
    public ProfileResponse myProfile(@AuthenticationPrincipal AuthenticatedUser user) {
        return profileService.myProfile(user);
    }
}
