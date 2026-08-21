package com.apa.auth.exception;

import com.apa.auth.social.SocialVerificationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler
    public ResponseEntity<String> handleUnauthorized(UnauthorizedException e) {
        return ResponseEntity
                .status(HttpStatus.UNAUTHORIZED)
                .body(e.getMessage());
    }

    /**
     * 소셜 토큰 검증 실패.
     *
     * <p><b>제공자 장애와 토큰 문제를 다른 코드로 낸다.</b> 카카오가 죽었을 때 401 을 내면
     * 프론트의 refresh 인터셉터가 재발급을 시도하고, 그것도 실패해 <b>토큰을 지워버린다</b> —
     * 남의 장애 때문에 멀쩡히 로그인해 있던 사용자가 로그아웃된다. 503 이면 그 경로를 타지 않는다.
     */
    @ExceptionHandler
    public ProblemDetail handleSocialVerification(SocialVerificationException e) {
        HttpStatus status = e.isProviderUnavailable()
                ? HttpStatus.SERVICE_UNAVAILABLE
                : HttpStatus.UNAUTHORIZED;

        ProblemDetail detail = ProblemDetail.forStatus(status);
        detail.setDetail(e.getMessage());
        return detail;
    }
}
