package com.apa.auth.dto;

/**
 * {@code POST /auth/signup} — 소셜 없이 이메일·비밀번호로 가입한다.
 *
 * @param nickname 비워 두면 이메일 앞부분으로 만든다. 주소 전체를 쓰지는 않는다
 * @param appId    {@code FISHING} 같은 앱 식별자. 계정은 APA 공통이고 앱 사용 이력만 나뉜다
 */
public record EmailSignUpRequest(String email, String password, String nickname, String appId) {
}
