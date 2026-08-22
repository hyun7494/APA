package com.apa.auth.service;

import com.apa.auth.exception.BadRequestException;

/**
 * 비밀번호 규칙.
 *
 * <p>길이만 본다. 대문자·특수문자를 강제하면 사용자는 {@code Password1!} 같은 예측 가능한
 * 형태로 몰리고, 실제로 막아야 할 짧은 비밀번호는 그대로 통과한다.
 */
public final class PasswordPolicy {

    static final int MIN_LENGTH = 8;

    /**
     * BCrypt 는 72바이트를 넘는 입력을 잘라 버린다. 잘린다는 사실을 모른 채 받으면
     * 아주 긴 비밀번호 두 개가 같은 것으로 취급되므로, 여기서 명시적으로 거절한다.
     */
    static final int MAX_LENGTH = 72;

    private PasswordPolicy() {
    }

    public static String require(String raw) {
        if (raw == null || raw.isEmpty()) {
            throw new BadRequestException("비밀번호를 입력해 주세요");
        }
        if (raw.length() < MIN_LENGTH) {
            throw new BadRequestException("비밀번호는 " + MIN_LENGTH + "자 이상이어야 합니다");
        }
        // 한글 한 글자가 UTF-8 로 3바이트다. 글자 수가 아니라 바이트로 재야 한다.
        if (raw.getBytes(java.nio.charset.StandardCharsets.UTF_8).length > MAX_LENGTH) {
            throw new BadRequestException("비밀번호가 너무 깁니다");
        }
        return raw;
    }
}
