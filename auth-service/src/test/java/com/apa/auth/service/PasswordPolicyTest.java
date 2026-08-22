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
    @DisplayName("★ 72바이트를 넘으면 거절한다 — BCrypt 가 조용히 잘라 버린다")
    void rejectsBeyondBcryptLimit() {
        // 한글은 UTF-8 로 한 글자 3바이트다. 25자면 75바이트라 글자 수로는 짧아 보인다.
        assertThatThrownBy(() -> PasswordPolicy.require("비".repeat(25)))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("깁니다");

        assertThat(PasswordPolicy.require("비".repeat(24))).hasSize(24);
    }
}
