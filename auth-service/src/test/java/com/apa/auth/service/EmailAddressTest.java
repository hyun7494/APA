package com.apa.auth.service;

import com.apa.auth.exception.BadRequestException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class EmailAddressTest {

    @Test
    @DisplayName("★ 대문자로 가입해도 소문자로 저장한다 — 안 그러면 계정이 둘로 갈린다")
    void normalizesCase() {
        assertThat(EmailAddress.require("  Hong@Gmail.COM ")).isEqualTo("hong@gmail.com");
        assertThat(EmailAddress.normalize("  Hong@Gmail.COM ")).isEqualTo("hong@gmail.com");
    }

    @Test
    @DisplayName("형식이 틀리면 가입을 거절한다")
    void rejectsMalformed() {
        for (String bad : new String[]{"hong", "hong@", "@gmail.com", "hong@gmail", "a b@c.com"}) {
            assertThatThrownBy(() -> EmailAddress.require(bad))
                    .as(bad)
                    .isInstanceOf(BadRequestException.class);
        }
    }

    @Test
    @DisplayName("빈 값은 형식이 아니라 '입력해 주세요' 로 안내한다")
    void rejectsBlank() {
        assertThatThrownBy(() -> EmailAddress.require("  "))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("입력");
    }

    @Test
    @DisplayName("★ 로그인 쪽은 형식이 틀려도 400 을 내지 않는다 (가입 여부를 떠볼 수 없게)")
    void normalizeIsLenient() {
        assertThat(EmailAddress.normalize("not-an-email")).isEqualTo("not-an-email");
        assertThat(EmailAddress.normalize("  ")).isNull();
        assertThat(EmailAddress.normalize(null)).isNull();
    }

    @Test
    @DisplayName("닉네임은 @ 앞부분만 쓴다 — 주소가 게시판에 그대로 노출되면 안 된다")
    void derivesNickname() {
        assertThat(EmailAddress.toNickname("hong@gmail.com")).isEqualTo("hong");
        assertThat(EmailAddress.toNickname("a".repeat(40) + "@gmail.com")).hasSize(30);
    }
}
