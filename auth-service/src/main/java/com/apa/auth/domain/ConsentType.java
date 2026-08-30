package com.apa.auth.domain;

import java.util.Arrays;
import java.util.List;

/**
 * 가입할 때 받는 동의 항목 (개인정보보호법 기준).
 *
 * <p><b>필수와 선택을 나누는 것이 핵심이다.</b> 선택 항목을 거부해도 가입은 되어야 한다 —
 * 선택 동의를 가입 조건으로 걸면 그건 동의가 아니라 강요이고, 법이 금지하는 쪽이다.
 *
 * <p>DB 에는 이 이름을 문자열로 넣는다({@code user_consents.consent_type}). enum 컬럼이
 * 아니라 문자열이라 항목이 늘어도 마이그레이션이 필요 없다 — 대신 <b>이름을 바꾸면
 * 과거 기록과 이어지지 않으니</b> 바꾸지 말 것.
 */
public enum ConsentType {

    /** 서비스 이용약관. */
    TERMS_OF_SERVICE(true),

    /** 개인정보 수집·이용 동의. */
    PRIVACY_POLICY(true),

    /**
     * 만 14세 이상임을 확인한다.
     *
     * <p>만 14세 미만은 법정대리인 동의가 있어야 개인정보를 처리할 수 있다. 그 절차를
     * 갖추기 전까지는 <b>가입 자체를 막는 것</b>이 유일하게 지킬 수 있는 선이다.
     */
    AGE_14(true),

    /** 마케팅 정보 수신. <b>선택이다.</b> */
    MARKETING(false);

    private final boolean required;

    ConsentType(boolean required) {
        this.required = required;
    }

    public boolean isRequired() {
        return required;
    }

    public static List<ConsentType> required() {
        return Arrays.stream(values()).filter(ConsentType::isRequired).toList();
    }

    /**
     * 모르는 코드는 <b>거절한다</b>. 조용히 무시하면 오타 하나로 필수 동의가 빠진 채
     * 가입이 되고, 그 사실을 아무도 모른다.
     */
    public static ConsentType of(String code) {
        return Arrays.stream(values())
                .filter(type -> type.name().equalsIgnoreCase(code))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("알 수 없는 동의 항목: " + code));
    }
}
