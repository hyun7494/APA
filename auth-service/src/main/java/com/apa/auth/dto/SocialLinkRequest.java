package com.apa.auth.dto;

/**
 * {@code POST /auth/link/social} — {@code POST /auth/login} 이 409 {@code LINK_REQUIRED} 를
 * 냈을 때 프론트가 비밀번호를 받아 다시 부른다.
 *
 * @param token    <b>같은 소셜 토큰을 다시 보낸다.</b> 서버는 이 토큰을 한 번 더 검증한다 —
 *                 앞선 요청의 결과를 세션에 들고 있다가 믿으면, 그 사이에 아무 값이나
 *                 끼워 넣을 여지가 생긴다
 * @param password 기존 자체 가입 계정의 비밀번호. 두 신원이 같은 사람의 것이라는 증거다
 */
public record SocialLinkRequest(String provider, String token, String password, String appId) {
}
