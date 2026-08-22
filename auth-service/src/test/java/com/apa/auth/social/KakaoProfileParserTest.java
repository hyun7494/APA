package com.apa.auth.social;

import com.apa.auth.domain.SocialType;
import com.apa.auth.social.kakao.KakaoProfileParser;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class KakaoProfileParserTest {

    /** 프로필 동의를 받은 정상 응답. */
    private static Map<String, Object> withProfile() {
        Map<String, Object> profile = new HashMap<>();
        profile.put("nickname", "감성돔사냥꾼");
        profile.put("profile_image_url", "https://k.kakaocdn.net/img_640x640.jpg");
        profile.put("thumbnail_image_url", "https://k.kakaocdn.net/img_110x110.jpg");

        Map<String, Object> account = new HashMap<>();
        account.put("profile", profile);

        Map<String, Object> body = new HashMap<>();
        body.put("id", 3_912_345_678L);
        body.put("kakao_account", account);
        return body;
    }

    @Test
    @DisplayName("정상 응답에서 신원을 뽑는다")
    void parsesProfile() {
        SocialProfile parsed = KakaoProfileParser.parse(withProfile());

        assertThat(parsed.socialType()).isEqualTo(SocialType.KAKAO);
        assertThat(parsed.socialId()).isEqualTo("3912345678");
        assertThat(parsed.nickname()).isEqualTo("감성돔사냥꾼");
        assertThat(parsed.profileUrl()).isEqualTo("https://k.kakaocdn.net/img_640x640.jpg");
    }

    @Test
    @DisplayName("★ id 가 int 범위를 넘어도 정확히 옮긴다")
    void keepsLargeIdExact() {
        Map<String, Object> body = withProfile();
        body.put("id", 4_123_456_789_012L);

        assertThat(KakaoProfileParser.parse(body).socialId()).isEqualTo("4123456789012");
    }

    @Test
    @DisplayName("★ 프로필 동의를 거부해도 로그인은 된다 (닉네임 없이)")
    void allowsNoConsent() {
        Map<String, Object> body = new HashMap<>();
        body.put("id", 3_912_345_678L);
        Map<String, Object> account = new HashMap<>();
        account.put("profile_nickname_needs_agreement", true);
        body.put("kakao_account", account);

        SocialProfile parsed = KakaoProfileParser.parse(body);

        assertThat(parsed.socialId()).isEqualTo("3912345678");
        assertThat(parsed.nickname()).isNull();
        assertThat(parsed.profileUrl()).isNull();
    }

    @Test
    @DisplayName("구버전 properties 필드로도 닉네임을 찾는다")
    void fallsBackToProperties() {
        Map<String, Object> properties = new HashMap<>();
        properties.put("nickname", "돌돔");
        properties.put("profile_image", "https://k.kakaocdn.net/old.jpg");

        Map<String, Object> body = new HashMap<>();
        body.put("id", 1L);
        body.put("properties", properties);

        SocialProfile parsed = KakaoProfileParser.parse(body);
        assertThat(parsed.nickname()).isEqualTo("돌돔");
        assertThat(parsed.profileUrl()).isEqualTo("https://k.kakaocdn.net/old.jpg");
    }

    @Test
    @DisplayName("프로필 이미지가 없으면 썸네일이라도 쓴다")
    void fallsBackToThumbnail() {
        Map<String, Object> body = withProfile();
        @SuppressWarnings("unchecked")
        Map<String, Object> account = (Map<String, Object>) body.get("kakao_account");
        @SuppressWarnings("unchecked")
        Map<String, Object> profile = (Map<String, Object>) account.get("profile");
        profile.remove("profile_image_url");

        assertThat(KakaoProfileParser.parse(body).profileUrl())
                .isEqualTo("https://k.kakaocdn.net/img_110x110.jpg");
    }

    @Test
    @DisplayName("id 가 없으면 신원을 만들 수 없다")
    void rejectsMissingId() {
        Map<String, Object> body = withProfile();
        body.remove("id");

        assertThatThrownBy(() -> KakaoProfileParser.parse(body))
                .isInstanceOf(SocialVerificationException.class)
                .hasMessageContaining("id");
    }

    @Test
    @DisplayName("인증된 이메일이면 연동에 쓸 수 있다 (소문자로 맞춰서)")
    void readsVerifiedEmail() {
        Map<String, Object> body = withProfile();
        @SuppressWarnings("unchecked")
        Map<String, Object> account = (Map<String, Object>) body.get("kakao_account");
        account.put("email", "Hong@Kakao.com");
        account.put("is_email_verified", true);

        SocialProfile parsed = KakaoProfileParser.parse(body);

        assertThat(parsed.email()).isEqualTo("hong@kakao.com");
        assertThat(parsed.hasVerifiedEmail()).isTrue();
    }

    @Test
    @DisplayName("★ 미인증 이메일로는 계정을 잇지 않는다")
    void doesNotTrustUnverifiedEmail() {
        Map<String, Object> body = withProfile();
        @SuppressWarnings("unchecked")
        Map<String, Object> account = (Map<String, Object>) body.get("kakao_account");
        account.put("email", "hong@kakao.com");
        account.put("is_email_verified", false);

        SocialProfile parsed = KakaoProfileParser.parse(body);

        assertThat(parsed.email()).isEqualTo("hong@kakao.com");
        assertThat(parsed.hasVerifiedEmail()).isFalse();
    }

    @Test
    @DisplayName("이메일 동의를 안 받았으면 주소가 없다")
    void allowsMissingEmail() {
        SocialProfile parsed = KakaoProfileParser.parse(withProfile());

        assertThat(parsed.email()).isNull();
        assertThat(parsed.hasVerifiedEmail()).isFalse();
    }

    @Test
    @DisplayName("빈 응답을 거절한다")
    void rejectsNullBody() {
        assertThatThrownBy(() -> KakaoProfileParser.parse(null))
                .isInstanceOf(SocialVerificationException.class);
    }
}
