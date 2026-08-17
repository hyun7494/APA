package com.apa.common.security;

import java.security.Principal;

/**
 * 요청을 보낸 사용자. JWT 에서 꺼낸 값이며 DB 조회 결과가 아니다.
 *
 * <p>각 앱은 이걸 {@code @AuthenticationPrincipal AuthenticatedUser user} 로 받아
 * {@code user.userId()} 를 자기 스키마의 {@code user_id} 컬럼에 쓴다 — 앱 서비스가
 * auth-service 를 다시 호출하지 않아도 되도록 <b>토큰 subject 가 userId</b> 다.
 *
 * <p>{@link Principal} 을 구현하는 이유는 {@code Authentication.getName()} 때문이다.
 * 구현하지 않으면 스프링이 principal 을 {@code toString()} 해서 레코드 전체가 이름으로 찍힌다.
 */
public record AuthenticatedUser(Long userId, String nickname) implements Principal {

    /** 닉네임이 없는 토큰(구버전·서비스 토큰)도 이름은 있어야 하므로 userId 로 떨어뜨린다. */
    @Override
    public String getName() {
        return nickname == null || nickname.isBlank() ? String.valueOf(userId) : nickname;
    }
}
