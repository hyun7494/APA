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
    public ProblemDetail handleBadRequest(BadRequestException e) {
        return problem(HttpStatus.BAD_REQUEST, e.getMessage(), "INVALID_INPUT");
    }

    /** 이미 쓰이고 있는 이메일·소셜 계정. */
    @ExceptionHandler
    public ProblemDetail handleConflict(ConflictException e) {
        return problem(HttpStatus.CONFLICT, e.getMessage(), "CONFLICT");
    }

    /**
     * 소셜 신원은 진짜인데 같은 이메일의 자체 가입 계정이 이미 있는 경우.
     *
     * <p><b>401 이 아니라 409 다.</b> 401 이면 프론트 인터셉터가 "로그인 실패"로 처리해
     * 토큰을 지우고 끝난다 — 사용자에게는 그냥 로그인이 안 되는 것으로 보인다. 409 에
     * {@code provider}·{@code email} 을 실어 주면 프론트가 비밀번호를 물어 연동을 이어갈 수 있다.
     */
    @ExceptionHandler
    public ProblemDetail handleLinkRequired(SocialLinkRequiredException e) {
        ProblemDetail detail = problem(HttpStatus.CONFLICT, e.getMessage(), SocialLinkRequiredException.CODE);
        detail.setProperty("email", e.getEmail());
        detail.setProperty("provider", e.getProvider().name());
        return detail;
    }

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

        return problem(status, e.getMessage(), "SOCIAL_VERIFICATION_FAILED");
    }

    /**
     * 프론트는 문구가 아니라 {@code code} 로 분기한다. 문구는 언제든 다듬지만
     * 코드가 바뀌면 클라이언트가 깨지므로, 둘을 갈라 둔다.
     */
    private ProblemDetail problem(HttpStatus status, String message, String code) {
        ProblemDetail detail = ProblemDetail.forStatus(status);
        detail.setDetail(message);
        detail.setProperty("code", code);
        return detail;
    }
}
