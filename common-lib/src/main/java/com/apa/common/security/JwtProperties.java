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

    /**
     * HS256 서명 키. <b>기본값이 없다</b> — 없이 뜨면 소스에 박힌 키로 아무나 토큰을
     * 위조할 수 있으므로, 부팅을 막는 편이 낫다.
     */
    private String secret;

    /** HS256 이 요구하는 최소 길이 (RFC 7518 §3.2). */
    private static final int MIN_SECRET_BYTES = 32;

    /**
     * 설정이 잘못됐을 때 <b>읽을 수 있는 이유</b>로 죽는다.
     *
     * <p>이게 없으면 JWT 라이브러리가 "The specified key byte array is 104 bits which is
     * not secure enough..." 같은 벽을 뱉는다 — 배포 중에 그걸 만나면 무엇을 고쳐야 할지
     * 알기까지 한참 걸린다. 여기서 먼저 잡아 환경변수 이름을 알려 준다.
     */
    @jakarta.annotation.PostConstruct
    void validate() {
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException(
                    "JWT_SECRET 이 없습니다. 32바이트 이상의 값을 환경변수로 주입하세요 "
                    + "(auth-service 와 app-* 이 같은 값이어야 합니다).");
        }
        int bytes = secret.getBytes(java.nio.charset.StandardCharsets.UTF_8).length;
        if (bytes < MIN_SECRET_BYTES) {
            throw new IllegalStateException(
                    "JWT_SECRET 이 너무 짧습니다: " + bytes + "바이트. "
                    + "HS256 은 " + MIN_SECRET_BYTES + "바이트 이상을 요구합니다 (RFC 7518 §3.2).");
        }
    }

    /**
     * 액세스 토큰 유효기간(ms). 검증만 하는 앱은 안 쓰므로 기본값을 둔다 —
     * app-fishing 처럼 발급하지 않는 모듈이 이 값을 yml 에 또 적을 이유가 없다.
     */
    private long expiration = 3_600_000L;
}
