package com.apa.auth.social.kakao;

import com.apa.auth.domain.SocialType;
import com.apa.auth.social.SocialProfile;
import com.apa.auth.social.SocialVerificationException;
import com.apa.auth.social.SocialVerifier;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import java.time.Duration;
import java.util.Map;

/**
 * 카카오 액세스 토큰 검증.
 *
 * <p>토큰을 들고 {@code /v2/user/me} 를 호출한다. 200 이면 그 토큰이 유효하고 응답의 {@code id}
 * 가 그 토큰의 주인이다 — <b>앱 키나 시크릿이 필요 없다.</b>
 */
@Component
public class KakaoVerifier implements SocialVerifier {

    private static final String USER_ME = "https://kapi.kakao.com/v2/user/me";

    /** 로그인 대기 중인 사용자가 보고 있다. 배치와 달리 길게 잡으면 안 된다. */
    private static final Duration TIMEOUT = Duration.ofSeconds(5);

    private final WebClient webClient;

    public KakaoVerifier(WebClient.Builder webClientBuilder) {
        this.webClient = webClientBuilder.build();
    }

    @Override
    public SocialType supports() {
        return SocialType.KAKAO;
    }

    @Override
    @SuppressWarnings("unchecked")
    public SocialProfile verify(String token) {
        Map<String, Object> body;
        try {
            body = webClient.get()
                    .uri(USER_ME)
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
                    .retrieve()
                    .bodyToMono(Map.class)
                    .block(TIMEOUT);
        } catch (WebClientResponseException.Unauthorized e) {
            // 카카오는 만료·위조를 모두 401 로 낸다. 사용자에게는 같은 안내로 충분하다.
            throw new SocialVerificationException("카카오 로그인 정보가 만료되었습니다. 다시 시도해 주세요");
        } catch (WebClientResponseException e) {
            throw SocialVerificationException.unavailable(
                    "카카오 응답이 올바르지 않습니다 (" + e.getStatusCode() + ")", e);
        } catch (RuntimeException e) {
            // 타임아웃·DNS·연결 거부. 사용자 잘못이 아니므로 401 로 내면 안 된다.
            throw SocialVerificationException.unavailable("카카오에 연결하지 못했습니다", e);
        }

        return KakaoProfileParser.parse(body);
    }
}
