package com.apa.auth.dto;

/**
 * {@code POST /auth/login} (기획서 v2 5-3).
 *
 * @param provider {@code KAKAO} / {@code GOOGLE}. 대소문자는 가리지 않는다
 * @param token    제공자 SDK 로 받은 토큰. 카카오는 <b>액세스 토큰</b>, 구글은 <b>ID 토큰</b>이다
 * @param appId    {@code FISHING} 같은 앱 식별자. 계정은 APA 공통이고 앱 사용 이력만 나뉜다
 */
public record SocialLoginRequest(String provider, String token, String appId) {
}
