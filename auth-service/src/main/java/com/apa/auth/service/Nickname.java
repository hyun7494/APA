package com.apa.auth.service;

import com.apa.auth.exception.BadRequestException;

import java.util.Locale;

/**
 * 닉네임 정규화. {@link EmailAddress} 와 같은 자리의 값 객체다.
 *
 * <p><b>저장·조회 양쪽에서 반드시 통과시킨다.</b> UNIQUE 인덱스가 {@code lower(nickname)}
 * 위에 걸려 있어서, 한쪽만 정규화하면 {@code Bada} 로 가입한 사람과 {@code bada} 가
 * 서로를 못 보는 채로 인덱스에서만 충돌한다.
 *
 * <p>막는 것은 <b>공백과 대소문자</b>뿐이다. 겉보기에 비슷한 글자(0/O, l/I, 한글 자모
 * 조합)까지 막으려 들면 정상적인 이름을 자꾸 거절하게 된다 — 사칭 대응은 신고로 한다.
 */
public final class Nickname {

    /** 컬럼이 30자다. */
    private static final int MAX_LENGTH = 30;

    private Nickname() {
    }

    /**
     * 앞뒤 공백을 떼고 가운데 연속 공백을 하나로 줄인다.
     *
     * <p>{@code "바다  사나이"} 와 {@code "바다 사나이"} 를 다른 이름으로 두면 눈으로는
     * 구별할 수 없는 두 계정이 생긴다.
     *
     * @return 비어 있으면 {@code null}
     */
    public static String normalize(String raw) {
        if (raw == null) {
            return null;
        }
        String collapsed = raw.strip().replaceAll("\\s+", " ");
        return collapsed.isEmpty() ? null : collapsed;
    }

    /** 사용자가 <b>직접 적은</b> 닉네임. 형식이 틀리면 거절한다. */
    public static String require(String raw) {
        String normalized = normalize(raw);
        if (normalized == null) {
            throw new BadRequestException("닉네임을 입력해 주세요");
        }
        if (normalized.length() > MAX_LENGTH) {
            throw new BadRequestException("닉네임은 " + MAX_LENGTH + "자 이하여야 합니다");
        }
        return normalized;
    }

    /**
     * 중복 검사용 키. DB 인덱스가 {@code lower(nickname)} 이므로 같은 규칙으로 내린다.
     *
     * <p>{@link Locale#ROOT} 를 쓴다 — 터키어 로캘에서 {@code I} 가 점 없는 소문자로
     * 내려가면 서버 로캘에 따라 중복 판정이 달라진다.
     */
    public static String key(String nickname) {
        return nickname.toLowerCase(Locale.ROOT);
    }

    /**
     * 자동으로 붙여 주는 이름이 겹칠 때 뒤에 숫자를 붙인다.
     *
     * <p>사용자가 직접 적은 이름에는 <b>쓰지 않는다</b> — 적어 낸 이름을 말없이 바꿔
     * 주는 것보다 "이미 쓰는 이름입니다" 라고 되묻는 편이 낫다. 이메일 앞부분이나 소셜
     * 제공자가 준 이름처럼 <b>물어볼 사람이 없는 경우</b>에만 쓴다.
     *
     * <p>30자를 넘기지 않도록 앞을 잘라 자리를 만든다.
     *
     * @param taken 그 이름이 이미 쓰이는지 답하는 함수
     */
    public static String withSuffix(String base, int attempt, java.util.function.Predicate<String> taken) {
        String candidate = base;
        int n = attempt;
        while (taken.test(candidate)) {
            String suffix = String.valueOf(++n);
            int room = MAX_LENGTH - suffix.length();
            candidate = (base.length() <= room ? base : base.substring(0, room)) + suffix;
        }
        return candidate;
    }
}
