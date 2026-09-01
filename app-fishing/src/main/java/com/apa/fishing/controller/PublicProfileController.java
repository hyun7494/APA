package com.apa.fishing.controller;

import com.apa.fishing.dto.PublicProfileResponse;
import com.apa.fishing.service.PublicProfileService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 공개 프로필 (계약서 3-10).
 *
 * <p>경로가 {@code /fishing/users/**} 라 {@code /fishing/me/**} 관문 밖이다 —
 * <b>비로그인도 볼 수 있다.</b> 게시판이 그렇듯 읽기는 열려 있다.
 */
@RestController
@RequestMapping("/fishing/users")
@RequiredArgsConstructor
public class PublicProfileController {

    private final PublicProfileService publicProfileService;

    @GetMapping("/{userId}")
    public PublicProfileResponse profile(@PathVariable Long userId) {
        return publicProfileService.of(userId);
    }
}
