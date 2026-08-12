package com.apa.fishing.batch.kma;

import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 공공데이터포털 요청 URI 조립. <b>인코딩을 우리가 직접, 정확히 한 번만</b> 하기 위한 것이다.
 *
 * <p>WebClient 의 {@code uriBuilder.queryParam(...)} 에 맡기면 안 된다. 기본 인코딩 모드는
 * 쿼리 파라미터 값의 {@code +} 를 <b>그대로 둔다</b>(RFC 3986 상 query 에서 허용되는 문자라서).
 * 그런데 포털 Decoding 키에는 {@code +} 와 {@code /} 가 흔히 들어 있고, 서버는 쿼리의 {@code +}
 * 를 <b>공백으로 해석</b>한다. 결과는 {@code SERVICE_KEY_IS_NOT_REGISTERED_ERROR} —
 * 키가 틀렸을 때와 메시지가 같아서 며칠을 날리기 딱 좋다.
 *
 * <p>{@link URLEncoder} 는 {@code +} → {@code %2B}, {@code /} → {@code %2F} 로 확실히 바꾼다.
 * 완성된 {@link URI} 를 {@code WebClient.uri(URI)} 에 넘기면 추가 인코딩이 일어나지 않는다.
 *
 * <p>한글 파라미터(바다낚시지수의 {@code gubun=갯바위})도 같은 경로로 처리된다.
 */
public final class PublicApiUri {

    private PublicApiUri() {
    }

    public static Builder of(String endpoint) {
        return new Builder(endpoint);
    }

    public static final class Builder {

        private final String endpoint;
        private final Map<String, String> params = new LinkedHashMap<>();

        private Builder(String endpoint) {
            this.endpoint = endpoint;
        }

        public Builder param(String name, Object value) {
            params.put(name, String.valueOf(value));
            return this;
        }

        public URI build() {
            StringBuilder sb = new StringBuilder(endpoint);
            char separator = '?';
            for (Map.Entry<String, String> entry : params.entrySet()) {
                sb.append(separator)
                        .append(encode(entry.getKey()))
                        .append('=')
                        .append(encode(entry.getValue()));
                separator = '&';
            }
            // URI.create 는 이미 인코딩된 문자열을 다시 건드리지 않는다
            return URI.create(sb.toString());
        }

        private static String encode(String value) {
            return URLEncoder.encode(value, StandardCharsets.UTF_8);
        }
    }
}
