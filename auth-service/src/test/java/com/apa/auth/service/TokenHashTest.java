package com.apa.auth.service;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.HashSet;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

class TokenHashTest {

    @Test
    @DisplayName("★ 저장하는 값에서 원문을 되돌릴 수 없다")
    void hashIsNotTheToken() {
        String token = TokenHash.newToken();

        assertThat(TokenHash.hash(token)).isNotEqualTo(token).doesNotContain(token);
    }

    @Test
    @DisplayName("같은 토큰은 같은 해시 — 조회가 인덱스 한 번으로 끝난다")
    void hashIsDeterministic() {
        String token = TokenHash.newToken();

        assertThat(TokenHash.hash(token)).isEqualTo(TokenHash.hash(token));
    }

    @Test
    @DisplayName("해시는 컬럼(255)에 들어가는 64자 hex 다")
    void hashFitsColumn() {
        assertThat(TokenHash.hash(TokenHash.newToken()))
                .hasSize(64)
                .matches("[0-9a-f]+");
    }

    @Test
    @DisplayName("토큰은 매번 다르다")
    void tokensAreUnique() {
        Set<String> seen = new HashSet<>();
        for (int i = 0; i < 1000; i++) {
            seen.add(TokenHash.newToken());
        }
        assertThat(seen).hasSize(1000);
    }

    @Test
    @DisplayName("토큰은 URL·헤더에 그대로 실을 수 있는 문자만 쓴다")
    void tokenIsUrlSafe() {
        assertThat(TokenHash.newToken()).matches("[A-Za-z0-9_-]+");
    }
}
