package com.apa.auth.social.google;

import com.apa.auth.domain.SocialType;
import com.apa.auth.social.SocialProfile;
import com.apa.auth.social.SocialVerificationException;

import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 구글 {@code tokeninfo} 응답 → {@link SocialProfile}.
 *
 * <p>구글 엔드포인트가 서명·만료를 대신 검증해 주지만 <b>그것만으로는 부족하다.</b>
 * 200 이 돌아왔다는 건 "이 ID 토큰이 구글이 발급한 진짜"라는 뜻일 뿐,
 * <b>우리 앱을 위해 발급된 것인지는 말해 주지 않는다.</b>
 */
public final class GoogleTokenInfoParser {

    private static final Set<String> VALID_ISSUERS =
            Set.of("accounts.google.com", "https://accounts.google.com");

    private GoogleTokenInfoParser() {
    }

    /**
     * @param allowedAudiences 우리 OAuth 클라이언트 ID 들. 플랫폼마다 달라서 여러 개다
     *                         (안드로이드는 serverClientId, iOS 는 iOS 클라이언트 ID)
     * @throws SocialVerificationException {@code aud} 가 우리 것이 아닐 때.
     *         <b>이 검사를 빼면 아무 구글 앱의 토큰으로나 남의 계정에 로그인할 수 있다</b> —
     *         공격자가 자기 앱에서 받은 피해자의 ID 토큰을 그대로 우리에게 내밀면 되기 때문이다
     */
    public static SocialProfile parse(Map<String, Object> body, List<String> allowedAudiences) {
        if (body == null) {
            throw new SocialVerificationException("구글 응답이 비어 있습니다");
        }
        if (body.get("error") != null || body.get("error_description") != null) {
            throw new SocialVerificationException("구글이 토큰을 거절했습니다");
        }

        String issuer = str(body.get("iss"));
        if (issuer != null && !VALID_ISSUERS.contains(issuer)) {
            throw new SocialVerificationException("구글이 발급한 토큰이 아닙니다");
        }

        String audience = str(body.get("aud"));
        if (allowedAudiences == null || allowedAudiences.isEmpty()) {
            // 설정을 비워 두면 검사가 통째로 사라진다. 조용히 통과시키는 것이 제일 위험하다.
            throw new SocialVerificationException(
                    "구글 클라이언트 ID 가 설정되지 않아 토큰을 검증할 수 없습니다");
        }
        if (audience == null || !allowedAudiences.contains(audience)) {
            throw new SocialVerificationException("이 앱을 위해 발급된 구글 토큰이 아닙니다");
        }

        String subject = str(body.get("sub"));
        if (subject == null || subject.isBlank()) {
            throw new SocialVerificationException("구글 응답에 sub 가 없습니다");
        }

        return new SocialProfile(
                SocialType.GOOGLE,
                subject,
                blankToNull(str(body.get("name"))),
                blankToNull(str(body.get("picture"))));
    }

    private static String str(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value;
    }
}
