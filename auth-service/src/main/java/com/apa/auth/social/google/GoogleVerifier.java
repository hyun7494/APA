package com.apa.auth.social.google;

import com.apa.auth.config.SocialProperties;
import com.apa.auth.domain.SocialType;
import com.apa.auth.social.SocialProfile;
import com.apa.auth.social.SocialVerificationException;
import com.apa.auth.social.SocialVerifier;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.time.Duration;
import java.util.Map;

/**
 * 구글 ID 토큰 검증.
 *
 * <p>공개 키를 받아 서명을 직접 검증하는 대신 구글의 {@code tokeninfo} 를 부른다. 키 롤오버를
 * 우리가 따라다니지 않아도 되고, 로그인 빈도에서 이 왕복은 문제가 되지 않는다.
 *
 * <p><b>액세스 토큰이 아니라 ID 토큰이다.</b> 프론트 {@code google_sign_in} 의
 * {@code idToken} 을 보내야 한다. 액세스 토큰을 보내면 여기서 400 이 난다.
 */
@Component
public class GoogleVerifier implements SocialVerifier {

    private static final String TOKEN_INFO = "https://oauth2.googleapis.com/tokeninfo";

    private static final Duration TIMEOUT = Duration.ofSeconds(5);

    private final WebClient webClient;
    private final SocialProperties properties;

    public GoogleVerifier(WebClient.Builder webClientBuilder, SocialProperties properties) {
        this.webClient = webClientBuilder.build();
        this.properties = properties;
    }

    @Override
    public SocialType supports() {
        return SocialType.GOOGLE;
    }

    @Override
    @SuppressWarnings("unchecked")
    public SocialProfile verify(String token) {
        URI uri = UriComponentsBuilder.fromUriString(TOKEN_INFO)
                .queryParam("id_token", token)
                .build(true)
                .toUri();

        Map<String, Object> body;
        try {
            body = webClient.get()
                    .uri(uri)
                    .retrieve()
                    .bodyToMono(Map.class)
                    .block(TIMEOUT);
        } catch (WebClientResponseException.BadRequest e) {
            // 구글은 만료·위조·형식 오류를 전부 400 으로 낸다.
            throw new SocialVerificationException("구글 로그인 정보가 만료되었습니다. 다시 시도해 주세요");
        } catch (WebClientResponseException e) {
            throw SocialVerificationException.unavailable(
                    "구글 응답이 올바르지 않습니다 (" + e.getStatusCode() + ")", e);
        } catch (RuntimeException e) {
            throw SocialVerificationException.unavailable("구글에 연결하지 못했습니다", e);
        }

        return GoogleTokenInfoParser.parse(body, properties.googleAudiences());
    }
}
