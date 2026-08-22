package com.apa.auth.service;

import com.apa.auth.exception.BadRequestException;

import java.util.Locale;
import java.util.regex.Pattern;

/**
 * 이메일 정규화.
 *
 * <p><b>저장·조회 양쪽에서 반드시 통과시킨다.</b> 컬럼 UNIQUE 는 대소문자를 구분하므로
 * 한쪽만 소문자로 내리면 {@code A@b.com} 으로 가입한 사람이 {@code a@b.com} 으로는 못
 * 들어오고, 같은 주소로 계정이 두 개 생긴다.
 */
public final class EmailAddress {

    /**
     * 실용적인 수준의 형식 검사다. RFC 5322 를 정확히 구현하려 들면 정규식이 읽을 수 없게
     * 길어지는데, 어차피 진짜 검증은 확인 메일이 한다. 여기서는 오타를 걸러 낼 뿐이다.
     */
    private static final Pattern FORMAT = Pattern.compile("^[^\\s@]+@[^\\s@.]+(\\.[^\\s@.]+)+$");

    /** 컬럼이 255자다. */
    private static final int MAX_LENGTH = 255;

    private EmailAddress() {
    }

    /** 가입처럼 <b>새로 받는</b> 주소. 형식이 틀리면 거절한다. */
    public static String require(String raw) {
        String normalized = normalize(raw);
        if (normalized == null) {
            throw new BadRequestException("이메일을 입력해 주세요");
        }
        if (normalized.length() > MAX_LENGTH || !FORMAT.matcher(normalized).matches()) {
            throw new BadRequestException("이메일 형식이 올바르지 않습니다");
        }
        return normalized;
    }

    /**
     * 로그인처럼 <b>대조만 하는</b> 주소. 형식 오류로 400 을 내지 않는다 —
     * 어차피 조회에 실패해 같은 401 이 되고, 400 과 401 이 갈리면 그 차이만으로
     * 가입 여부를 떠볼 수 있는 신호가 된다.
     */
    public static String normalize(String raw) {
        if (raw == null || raw.isBlank()) return null;
        return raw.trim().toLowerCase(Locale.ROOT);
    }

    /**
     * 닉네임을 안 준 사용자에게 줄 이름. {@code hong@gmail.com} → {@code hong}.
     *
     * <p>주소 전체를 쓰면 게시판에 이메일이 그대로 노출된다.
     */
    public static String toNickname(String email) {
        int at = email.indexOf('@');
        String local = at > 0 ? email.substring(0, at) : email;
        return local.length() <= 30 ? local : local.substring(0, 30);
    }
}
