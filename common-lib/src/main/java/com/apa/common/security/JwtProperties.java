package com.apa.common.security;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * {@code jwt.*} 설정. <b>모든 앱이 같은 secret 을 써야 한다</b> — HS256 대칭키라
 * 발급(auth-service)과 검증(app-*)이 같은 키를 공유하지 않으면 전부 401 이 된다.
 */
@Getter
@Setter
@ConfigurationProperties(prefix = "jwt")
public class JwtProperties {

    private String secret;

    /**
     * 액세스 토큰 유효기간(ms). 검증만 하는 앱은 안 쓰므로 기본값을 둔다 —
     * app-fishing 처럼 발급하지 않는 모듈이 이 값을 yml 에 또 적을 이유가 없다.
     */
    private long expiration = 3_600_000L;
}
