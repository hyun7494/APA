package com.apa.auth.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.List;

/**
 * 소셜 제공자 설정.
 *
 * <p><b>비밀값이 아니다.</b> 구글 클라이언트 ID 는 앱에 박혀 배포되는 공개 값이고,
 * 카카오는 토큰 검증에 앱 키조차 필요 없다 (사용자 액세스 토큰만으로 조회한다).
 * 그래도 환경마다 달라서 설정으로 뺀다.
 *
 * @param googleAudiences 허용할 구글 {@code aud} 목록. 플랫폼마다 클라이언트 ID 가 다르다 —
 *                        안드로이드는 <b>웹 클라이언트 ID</b>(serverClientId)가 aud 로 오고,
 *                        iOS 는 iOS 클라이언트 ID 가 온다. 하나만 넣으면 다른 쪽이 전부 막힌다
 */
@ConfigurationProperties(prefix = "social")
public record SocialProperties(List<String> googleAudiences) {

    public SocialProperties {
        googleAudiences = googleAudiences == null ? List.of() : List.copyOf(googleAudiences);
    }
}
