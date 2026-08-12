package com.apa.fishing.batch.publicapi;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.net.URI;

import static org.assertj.core.api.Assertions.assertThat;

/** 인증키 인코딩은 이 프로젝트에서 제일 많이 걸린다는 함정이다. 여기서 못 박아둔다. */
class PublicApiUriTest {

    @Test
    @DisplayName("Decoding 키의 + / = 를 정확히 한 번 인코딩한다")
    void encodesDecodingKeyExactlyOnce() {
        // 포털 Decoding 키는 base64 라 +, /, = 가 섞여 나온다.
        URI uri = PublicApiUri.of("https://example.com/op")
                .param("serviceKey", "ab+cd/ef==")
                .build();

        assertThat(uri.toString()).isEqualTo("https://example.com/op?serviceKey=ab%2Bcd%2Fef%3D%3D");
    }

    @Test
    @DisplayName("이미 인코딩된 값을 또 인코딩하지 않도록 % 자체를 escape 한다")
    void doubleEncodingIsVisibleNotSilent() {
        // Encoding 키를 잘못 넣으면 %2B -> %252B 가 된다. 조용히 통과하는 것보다
        // 이 동작을 테스트로 드러내 두는 편이 원인 추적에 낫다.
        URI uri = PublicApiUri.of("https://example.com/op")
                .param("serviceKey", "ab%2Bcd")
                .build();

        assertThat(uri.toString()).isEqualTo("https://example.com/op?serviceKey=ab%252Bcd");
    }

    @Test
    @DisplayName("한글 파라미터를 UTF-8 로 인코딩한다 — 바다낚시지수의 gubun=갯바위")
    void encodesKoreanParameter() {
        URI uri = PublicApiUri.of("https://example.com/op")
                .param("gubun", "갯바위")
                .build();

        assertThat(uri.toString()).isEqualTo("https://example.com/op?gubun=%EA%B0%AF%EB%B0%94%EC%9C%84");
    }

    @Test
    @DisplayName("파라미터 순서를 넣은 순서대로 유지한다 — 로그를 눈으로 비교하기 위해")
    void keepsParameterOrder() {
        URI uri = PublicApiUri.of("https://example.com/op")
                .param("a", 1)
                .param("b", 2)
                .param("c", 3)
                .build();

        assertThat(uri.toString()).isEqualTo("https://example.com/op?a=1&b=2&c=3");
    }
}
