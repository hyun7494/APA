package com.apa.auth.domain;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 동의 항목의 필수/선택 구분. 스프링 없이 도는 부분이다.
 *
 * <p>여기서 지키는 건 <b>법에서 오는 규칙</b>이라 우연히 바뀌면 안 된다.
 */
class ConsentTypeTest {

    @Test
    @DisplayName("★ 마케팅은 선택이다 — 선택 동의를 가입 조건으로 걸면 강요가 된다")
    void marketingIsOptional() {
        assertThat(ConsentType.MARKETING.isRequired()).isFalse();
        assertThat(ConsentType.required()).doesNotContain(ConsentType.MARKETING);
    }

    @Test
    @DisplayName("★ 약관·개인정보·만14세는 필수다")
    void theRestAreRequired() {
        assertThat(ConsentType.required()).containsExactlyInAnyOrder(
                ConsentType.TERMS_OF_SERVICE,
                ConsentType.PRIVACY_POLICY,
                ConsentType.AGE_14);
    }

    @Test
    @DisplayName("★ 모르는 코드는 거절한다 — 조용히 무시하면 오타 하나로 필수 동의가 빠진다")
    void rejectsUnknownCode() {
        assertThatThrownBy(() -> ConsentType.of("TERMS"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("알 수 없는 동의 항목");
    }

    @Test
    @DisplayName("대소문자는 가린다 — 앱이 소문자로 보내도 같은 항목이다")
    void acceptsAnyCase() {
        assertThat(ConsentType.of("privacy_policy")).isEqualTo(ConsentType.PRIVACY_POLICY);
    }

    @Test
    @DisplayName("★ 이름은 DB 에 그대로 들어간다 — 바꾸면 과거 기록과 이어지지 않는다")
    void namesAreTheStoredCodes() {
        // 이 목록이 바뀌면 user_consents.consent_type 의 과거 값과 어긋난다.
        assertThat(ConsentType.values())
                .extracting(Enum::name)
                .containsExactly("TERMS_OF_SERVICE", "PRIVACY_POLICY", "AGE_14", "MARKETING");
    }
}
