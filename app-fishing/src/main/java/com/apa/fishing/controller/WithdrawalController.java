package com.apa.fishing.controller;

import com.apa.common.security.AuthenticatedUser;
import com.apa.fishing.service.WithdrawalService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 탈퇴 시 이 서비스의 흔적을 정리한다 (계약서 3-9).
 *
 * <p>★ <b>계정을 없애지 않는다.</b> 계정은 auth-service 소관이고, 앱이 이 요청을 먼저 보낸
 * 뒤 {@code DELETE /auth/me} 를 부른다. 순서를 뒤집으면 토큰이 죽어 이 요청을 못 보낸다.
 *
 * <p>경로가 {@code /fishing/me/**} 아래라 SecurityConfig 가 비로그인을 이미 401 로 끊는다.
 */
@RestController
@RequestMapping("/fishing/me")
@RequiredArgsConstructor
public class WithdrawalController {

    private final WithdrawalService withdrawalService;

    /** 여러 번 불러도 같다 — 앱이 중간에 실패해 다시 눌러도 안전하다. */
    @DeleteMapping
    public ResponseEntity<Void> withdraw(@AuthenticationPrincipal AuthenticatedUser user) {
        withdrawalService.withdraw(user.userId());
        return ResponseEntity.noContent().build();
    }
}
