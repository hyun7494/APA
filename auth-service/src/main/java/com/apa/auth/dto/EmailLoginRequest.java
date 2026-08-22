package com.apa.auth.dto;

/** {@code POST /auth/login/email} — 자체 가입 계정으로 로그인한다. */
public record EmailLoginRequest(String email, String password, String appId) {
}
