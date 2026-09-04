package com.apa.auth.service;

import java.util.Locale;
import java.util.Set;

import com.apa.auth.exception.BadRequestException;

/**
 * 비밀번호 규칙.
 *
 * <p>대문자·특수문자를 <b>강제하지 않는다.</b> 그렇게 하면 사용자는 {@code Password1!} 같은
 * 예측 가능한 형태로 몰리고, 실제로 막아야 할 <b>흔한 비밀번호</b>는 그대로 통과한다
 * (NIST SP 800-63B 도 구성 규칙 대신 <b>알려진 비밀번호 차단</b>을 권한다).
 *
 * <p>★ 그래서 길이 대신 <b>실제로 뚫리는 것</b>을 막는다 — 유출 목록 상위, 한 글자의 반복,
 * 연속된 숫자·자판, 그리고 <b>자기 이메일 아이디</b>. 예전에는 {@code 12345678} 이 그대로
 * 통과했고, 로그인 시도 제한도 없어서 그 조합이 실제 위험이었다.
 */
public final class PasswordPolicy {

    static final int MIN_LENGTH = 8;

    /**
     * BCrypt 는 72바이트를 넘는 입력을 잘라 버린다. 잘린다는 사실을 모른 채 받으면
     * 아주 긴 비밀번호 두 개가 같은 것으로 취급되므로, 여기서 명시적으로 거절한다.
     */
    static final int MAX_LENGTH = 72;

    /**
     * 유출 목록에서 늘 상위에 오는 것들. 전부 소문자로 둔다 — 비교할 때 낮춘다.
     *
     * <p>완전한 목록이 아니다. 제대로 하려면 유출 데이터셋(HIBP 등)을 붙여야 하지만,
     * 그건 외부 의존이라 나중 일이다. 이 짧은 목록만으로도 <b>실제로 가장 많이 뚫리는
     * 것들</b>은 걸러진다.
     */
    private static final Set<String> COMMON = Set.of(
            "12345678", "123456789", "1234567890", "password", "password1", "password123",
            "qwerty123", "qwertyui", "asdfasdf", "abc12345", "iloveyou", "princess",
            "admin123", "welcome1", "letmein1", "sunshine", "football", "baseball",
            "dragon123", "monkey12", "trustno1", "starwars", "whatever", "computer",
            "11111111", "00000000", "aaaaaaaa", "1q2w3e4r", "1qaz2wsx", "zaq12wsx");

    private PasswordPolicy() {
    }

    public static String require(String raw) {
        return require(raw, null);
    }

    /**
     * @param email 있으면 <b>아이디와 같은 비밀번호</b>도 막는다. 가장 먼저 시도되는 값이다.
     */
    public static String require(String raw, String email) {
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

        String lower = raw.toLowerCase(Locale.ROOT);
        if (COMMON.contains(lower)) {
            throw new BadRequestException("너무 흔한 비밀번호입니다. 다른 것을 써 주세요");
        }
        if (isSingleCharacter(lower) || isRun(lower)) {
            throw new BadRequestException("추측하기 쉬운 비밀번호입니다. 다른 것을 써 주세요");
        }
        if (containsLocalPart(lower, email)) {
            throw new BadRequestException("이메일 아이디가 들어간 비밀번호는 쓸 수 없습니다");
        }
        return raw;
    }

    /** {@code aaaaaaaa} 처럼 한 글자만 반복. */
    private static boolean isSingleCharacter(String lower) {
        return lower.chars().distinct().count() == 1;
    }

    /** {@code 12345678}·{@code abcdefgh} 처럼 하나씩 오르내리는 것 (뒤집힌 것도). */
    private static boolean isRun(String lower) {
        boolean up = true;
        boolean down = true;
        for (int i = 1; i < lower.length(); i++) {
            int diff = lower.charAt(i) - lower.charAt(i - 1);
            if (diff != 1) up = false;
            if (diff != -1) down = false;
        }
        return up || down;
    }

    /**
     * 이메일 아이디가 통째로 들어 있나. {@code hong@x.com} 이면 {@code hong1234} 를 막는다.
     *
     * <p>세 글자 미만은 보지 않는다 — 흔한 글자 묶음이라 애먼 비밀번호까지 막힌다.
     */
    private static boolean containsLocalPart(String lowerPassword, String email) {
        if (email == null) {
            return false;
        }
        int at = email.indexOf('@');
        String local = (at > 0 ? email.substring(0, at) : email).toLowerCase(Locale.ROOT).trim();
        return local.length() >= 3 && lowerPassword.contains(local);
    }
}
