package com.apa.auth.social;

import com.apa.auth.domain.SocialType;
import com.apa.auth.social.google.GoogleTokenInfoParser;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class GoogleTokenInfoParserTest {

    private static final String OUR_ANDROID = "111-android.apps.googleusercontent.com";
    private static final String OUR_IOS = "111-ios.apps.googleusercontent.com";
    private static final List<String> ALLOWED = List.of(OUR_ANDROID, OUR_IOS);

    private static Map<String, Object> validBody() {
        Map<String, Object> body = new HashMap<>();
        body.put("iss", "https://accounts.google.com");
        body.put("aud", OUR_ANDROID);
        body.put("sub", "108124094943712341234");
        body.put("name", "홍길동");
        body.put("picture", "https://lh3.googleusercontent.com/a/abc");
        body.put("email", "hong@gmail.com");
        return body;
    }

    @Test
    @DisplayName("정상 응답에서 신원을 뽑는다")
    void parsesValidToken() {
        SocialProfile profile = GoogleTokenInfoParser.parse(validBody(), ALLOWED);

        assertThat(profile.socialType()).isEqualTo(SocialType.GOOGLE);
        assertThat(profile.socialId()).isEqualTo("108124094943712341234");
        assertThat(profile.nickname()).isEqualTo("홍길동");
        assertThat(profile.profileUrl()).isEqualTo("https://lh3.googleusercontent.com/a/abc");
    }

    @Test
    @DisplayName("★ email_verified 는 문자열 \"true\" 로 온다 (JSON 불리언이 아니다)")
    void readsVerifiedEmail() {
        Map<String, Object> body = validBody();
        body.put("email", "Hong@Gmail.com");
        body.put("email_verified", "true");

        SocialProfile profile = GoogleTokenInfoParser.parse(body, ALLOWED);

        assertThat(profile.email()).isEqualTo("hong@gmail.com");
        assertThat(profile.hasVerifiedEmail()).isTrue();
    }

    @Test
    @DisplayName("email_verified 가 없으면 연동에 쓰지 않는다")
    void doesNotTrustUnverifiedEmail() {
        SocialProfile profile = GoogleTokenInfoParser.parse(validBody(), ALLOWED);

        assertThat(profile.email()).isEqualTo("hong@gmail.com");
        assertThat(profile.hasVerifiedEmail()).isFalse();
    }

    @Test
    @DisplayName("플랫폼별 클라이언트 ID 를 모두 허용한다")
    void acceptsAnyConfiguredAudience() {
        Map<String, Object> body = validBody();
        body.put("aud", OUR_IOS);

        assertThat(GoogleTokenInfoParser.parse(body, ALLOWED).socialId())
                .isEqualTo("108124094943712341234");
    }

    @Nested
    @DisplayName("aud 검증 — 빠지면 남의 앱 토큰으로 로그인된다")
    class Audience {

        @Test
        @DisplayName("★ 다른 앱을 위해 발급된 토큰은 거절한다")
        void rejectsForeignAudience() {
            Map<String, Object> body = validBody();
            body.put("aud", "999-someone-else.apps.googleusercontent.com");

            assertThatThrownBy(() -> GoogleTokenInfoParser.parse(body, ALLOWED))
                    .isInstanceOf(SocialVerificationException.class)
                    .hasMessageContaining("이 앱을 위해 발급된");
        }

        @Test
        @DisplayName("★ 설정이 비어 있으면 통과시키지 않고 실패한다")
        void failsClosedWhenUnconfigured() {
            assertThatThrownBy(() -> GoogleTokenInfoParser.parse(validBody(), List.of()))
                    .isInstanceOf(SocialVerificationException.class)
                    .hasMessageContaining("설정되지 않아");

            assertThatThrownBy(() -> GoogleTokenInfoParser.parse(validBody(), null))
                    .isInstanceOf(SocialVerificationException.class);
        }

        @Test
        @DisplayName("aud 가 없는 응답도 거절한다")
        void rejectsMissingAudience() {
            Map<String, Object> body = validBody();
            body.remove("aud");

            assertThatThrownBy(() -> GoogleTokenInfoParser.parse(body, ALLOWED))
                    .isInstanceOf(SocialVerificationException.class);
        }
    }

    @Test
    @DisplayName("구글이 아닌 발급자는 거절한다")
    void rejectsForeignIssuer() {
        Map<String, Object> body = validBody();
        body.put("iss", "https://evil.example.com");

        assertThatThrownBy(() -> GoogleTokenInfoParser.parse(body, ALLOWED))
                .isInstanceOf(SocialVerificationException.class)
                .hasMessageContaining("구글이 발급한");
    }

    @Test
    @DisplayName("iss 는 두 가지 표기를 모두 받는다")
    void acceptsBothIssuerForms() {
        Map<String, Object> body = validBody();
        body.put("iss", "accounts.google.com");

        assertThat(GoogleTokenInfoParser.parse(body, ALLOWED).socialId()).isNotBlank();
    }

    @Test
    @DisplayName("에러 응답은 거절한다")
    void rejectsErrorBody() {
        Map<String, Object> body = new HashMap<>();
        body.put("error", "invalid_token");

        assertThatThrownBy(() -> GoogleTokenInfoParser.parse(body, ALLOWED))
                .isInstanceOf(SocialVerificationException.class)
                .hasMessageContaining("거절");
    }

    @Test
    @DisplayName("sub 가 없으면 신원을 만들 수 없다")
    void rejectsMissingSubject() {
        Map<String, Object> body = validBody();
        body.remove("sub");

        assertThatThrownBy(() -> GoogleTokenInfoParser.parse(body, ALLOWED))
                .isInstanceOf(SocialVerificationException.class);
    }

    @Test
    @DisplayName("이름·사진이 없어도 로그인은 된다 (선택 동의 항목이다)")
    void allowsMissingProfile() {
        Map<String, Object> body = validBody();
        body.remove("name");
        body.remove("picture");

        SocialProfile profile = GoogleTokenInfoParser.parse(body, ALLOWED);
        assertThat(profile.nickname()).isNull();
        assertThat(profile.profileUrl()).isNull();
    }
}
