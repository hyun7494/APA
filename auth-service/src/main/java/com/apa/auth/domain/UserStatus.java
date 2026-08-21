package com.apa.auth.domain;

/** {@code users.status}. 탈퇴는 행을 지우지 않고 상태로 남긴다 — 조과·게시글이 user_id 를 참조한다. */
public enum UserStatus {
    ACTIVE,
    WITHDRAWN
}
