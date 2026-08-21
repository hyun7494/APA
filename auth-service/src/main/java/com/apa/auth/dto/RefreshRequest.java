package com.apa.auth.dto;

/** {@code POST /auth/refresh}. 프론트 {@code api_client.dart} 가 401 을 받으면 자동으로 부른다. */
public record RefreshRequest(String refreshToken) {
}
