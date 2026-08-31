package com.apa.auth.service;

import com.apa.auth.exception.BadRequestException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 닉네임 정규화. {@link EmailAddress} 와 같은 결의 값 객체라 같은 자리에서 검증한다.
 *
 * <p>UNIQUE 인덱스가 {@code lower(nickname)} 위에 있으므로, 여기서 내리는 규칙이
 * 인덱스와 어긋나면 <b>검사는 통과했는데 INSERT 에서 터진다.</b>
 */
class NicknameTest {

    @Test
    @DisplayName("★ 앞뒤 공백과 가운데 연속 공백을 정리한다 — 눈으로 같은 이름을 둘로 만들지 않는다")
    void collapsesWhitespace() {
        assertThat(Nickname.normalize("  바다사나이  ")).isEqualTo("바다사나이");
        assertThat(Nickname.normalize("바다  사나이")).isEqualTo("바다 사나이");
        assertThat(Nickname.normalize("바다\t사나이")).isEqualTo("바다 사나이");
    }

    @Test
    @DisplayName("빈 값은 null 이다 — 자동으로 지어 줄지 판단하는 쪽이 쓴다")
    void blankIsNull() {
        assertThat(Nickname.normalize(null)).isNull();
        assertThat(Nickname.normalize("   ")).isNull();
    }

    @Test
    @DisplayName("★ 중복 키는 대소문자를 내린다 — Bada 와 bada 는 같은 이름이다")
    void keyIsCaseInsensitive() {
        assertThat(Nickname.key("Bada")).isEqualTo(Nickname.key("bada"));
    }

    @Test
    @DisplayName("30자를 넘으면 거절한다 — 컬럼이 30자다")
    void rejectsTooLong() {
        assertThatThrownBy(() -> Nickname.require("가".repeat(31)))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("30자");
    }

    @Test
    @DisplayName("직접 적은 닉네임이 비면 거절한다 — 여기서 지어 주지 않는다")
    void requiresSomething() {
        assertThatThrownBy(() -> Nickname.require("  "))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    @DisplayName("★ 자동 이름이 겹치면 숫자를 붙인다 (물어볼 사람이 없는 경우에만 쓴다)")
    void addsSuffixWhenTaken() {
        Set<String> taken = Set.of("hong", "hong1", "hong2");
        assertThat(Nickname.withSuffix("hong", 0, taken::contains)).isEqualTo("hong3");
    }

    @Test
    @DisplayName("안 겹치면 그대로 둔다")
    void keepsFreeName() {
        assertThat(Nickname.withSuffix("hong", 0, name -> false)).isEqualTo("hong");
    }

    @Test
    @DisplayName("★ 숫자를 붙여도 30자를 넘지 않는다 — 앞을 잘라 자리를 만든다")
    void staysWithinColumnLength() {
        String base = "가".repeat(30);
        String result = Nickname.withSuffix(base, 0, name -> name.equals(base));

        assertThat(result).hasSizeLessThanOrEqualTo(30);
        assertThat(result).isNotEqualTo(base);
    }
}
