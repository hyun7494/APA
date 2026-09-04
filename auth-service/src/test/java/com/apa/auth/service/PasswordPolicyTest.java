package com.apa.auth.service;

import com.apa.auth.exception.BadRequestException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class PasswordPolicyTest {

    @Test
    @DisplayName("8자 이상이면 통과한다")
    void acceptsLongEnough() {
        assertThat(PasswordPolicy.require("hyun1234")).isEqualTo("hyun1234");
    }

    @Test
    @DisplayName("짧으면 거절한다")
    void rejectsShort() {
        assertThatThrownBy(() -> PasswordPolicy.require("hyun123"))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("8자");
    }

    @Test
    @DisplayName("빈 값을 거절한다")
    void rejectsBlank() {
        assertThatThrownBy(() -> PasswordPolicy.require(null))
                .isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> PasswordPolicy.require(""))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    @DisplayName("★ 흔한 비밀번호를 막는다 — 길이만 보면 12345678 이 통과한다")
    void rejectsCommonPasswords() {
        // 예전에는 이것들이 전부 통과했다. 시도 제한도 없어서 실제 위험이었다.
        for (String weak : new String[] {"12345678", "password", "qwerty123", "11111111"}) {
            assertThatThrownBy(() -> PasswordPolicy.require(weak))
                    .as(weak)
                    .isInstanceOf(BadRequestException.class);
        }
    }

    @Test
    @DisplayName("★ 한 글자 반복과 연속된 값을 막는다")
    void rejectsDegeneratePasswords() {
        assertThatThrownBy(() -> PasswordPolicy.require("aaaaaaaaaa"))
                .isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> PasswordPolicy.require("abcdefgh"))
                .isInstanceOf(BadRequestException.class);
        // 거꾸로도 마찬가지다.
        assertThatThrownBy(() -> PasswordPolicy.require("hgfedcba"))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    @DisplayName("★ 이메일 아이디가 든 비밀번호를 막는다 — 가장 먼저 시도되는 값이다")
    void rejectsPasswordContainingEmailLocalPart() {
        assertThatThrownBy(() -> PasswordPolicy.require("hong1234!", "hong@example.com"))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("이메일");

        // 이메일을 안 넘기면 이 검사는 돌지 않는다 (로그인처럼 검사할 이유가 없는 자리).
        assertThat(PasswordPolicy.require("hong1234!")).isNotEmpty();

        // 두 글자짜리 아이디까지 막으면 애먼 비밀번호가 걸린다.
        assertThat(PasswordPolicy.require("ab7Kq2mZ", "ab@example.com")).isNotEmpty();
    }

    @Test
    @DisplayName("★ 72바이트를 넘으면 거절한다 — BCrypt 가 조용히 잘라 버린다")
    void rejectsBeyondBcryptLimit() {
        // 한글은 UTF-8 로 한 글자 3바이트다. 25자면 75바이트라 글자 수로는 짧아 보인다.
        //
        // ⚠️ 한 글자를 반복하면 안 된다 — `비비비…` 는 이제 "추측하기 쉬움" 으로 먼저
        //    걸려서, 길이 검사를 보려던 이 테스트가 엉뚱한 이유로 통과/실패한다.
        //    두 글자를 번갈아 써서 길이만 재게 한다.
        assertThatThrownBy(() -> PasswordPolicy.require("비밀".repeat(12) + "번"))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("깁니다");

        assertThat(PasswordPolicy.require("비밀".repeat(12))).hasSize(24);
    }
}
