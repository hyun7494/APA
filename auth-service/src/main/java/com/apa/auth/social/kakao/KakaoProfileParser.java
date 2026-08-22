package com.apa.auth.social.kakao;

import com.apa.auth.domain.SocialType;
import com.apa.auth.social.SocialProfile;
import com.apa.auth.social.SocialVerificationException;

import java.util.Locale;
import java.util.Map;

/**
 * 카카오 {@code /v2/user/me} 응답 → {@link SocialProfile}.
 *
 * <p>HTTP 와 분리해 둔 순수 함수다. 카카오가 항목 이름을 바꾸면 여기 테스트가 깨져서 알려준다.
 */
public final class KakaoProfileParser {

    private KakaoProfileParser() {
    }

    /**
     * <p>닉네임이 <b>세 군데</b>에 있을 수 있다. 동의 항목 설정에 따라 어느 하나만 오거나
     * 하나도 안 온다:
     * <ol>
     *   <li>{@code kakao_account.profile.nickname} — 프로필 정보 동의</li>
     *   <li>{@code properties.nickname} — 구버전 필드. 아직 내려주는 앱이 있다</li>
     *   <li>없음 — 사용자가 프로필 제공에 동의하지 않은 경우</li>
     * </ol>
     * 셋째가 정상 흐름이라는 점이 중요하다. 닉네임이 없다고 로그인을 막으면
     * <b>동의를 거부한 사용자는 영영 들어올 수 없다.</b>
     */
    @SuppressWarnings("unchecked")
    public static SocialProfile parse(Map<String, Object> body) {
        if (body == null) {
            throw new SocialVerificationException("카카오 응답이 비어 있습니다");
        }

        Object id = body.get("id");
        if (id == null) {
            throw new SocialVerificationException("카카오 응답에 id 가 없습니다");
        }

        Map<String, Object> account = asMap(body.get("kakao_account"));
        Map<String, Object> profile = account == null ? null : asMap(account.get("profile"));
        Map<String, Object> properties = asMap(body.get("properties"));

        String nickname = firstNonBlank(
                profile == null ? null : str(profile.get("nickname")),
                properties == null ? null : str(properties.get("nickname")));

        String profileUrl = firstNonBlank(
                profile == null ? null : str(profile.get("profile_image_url")),
                profile == null ? null : str(profile.get("thumbnail_image_url")),
                properties == null ? null : str(properties.get("profile_image")));

        // 이메일은 별도 동의 항목이다. 동의를 안 받았으면 kakao_account 에 아예 없다.
        String email = account == null ? null : normalizeEmail(str(account.get("email")));
        // 카카오는 미인증 주소도 내려준다. 그대로 믿고 계정을 이어 붙이면 안 된다.
        boolean emailVerified = account != null && Boolean.TRUE.equals(account.get("is_email_verified"));

        // id 는 JSON 숫자라 Long 으로 오는데, 자리수가 커서 Integer 로 좁히면 안 된다.
        // 문자열로 바로 세운다.
        return new SocialProfile(
                SocialType.KAKAO, String.valueOf(id), nickname, profileUrl, email, emailVerified);
    }

    /** 계정 연동은 소문자 주소로 맞춰 본다. {@code A@Kakao.com} 이 다른 사람이 되면 안 된다. */
    private static String normalizeEmail(String value) {
        if (value == null || value.isBlank()) return null;
        return value.trim().toLowerCase(Locale.ROOT);
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> asMap(Object value) {
        return value instanceof Map<?, ?> map ? (Map<String, Object>) map : null;
    }

    private static String str(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static String firstNonBlank(String... values) {
        for (String value : values) {
            if (value != null && !value.isBlank()) return value;
        }
        return null;
    }
}
