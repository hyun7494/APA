package com.apa.fishing.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 공공데이터포털 인증키. {@code application.yml} 의 {@code fishing.api.*} 를 받는다.
 *
 * <p>⚠️ 포털은 Encoding / Decoding 두 벌을 준다. <b>Decoding 키를 넣어야 한다.</b>
 * Encoding 키(이미 퍼센트 인코딩된 문자열)를 넣으면 WebClient 가 한 번 더 인코딩해서
 * {@code %2B} 가 {@code %252B} 가 되고, 서버는 {@code SERVICE_KEY_IS_NOT_REGISTERED_ERROR}
 * 를 돌려준다. 키가 진짜 틀렸을 때와 <b>에러 메시지가 똑같아서</b> 원인을 가리기 어렵다.
 *
 * <p>기본값이 빈 문자열이라 키가 없어도 앱은 뜬다. 배치가 스스로 비활성화된다.
 */
@ConfigurationProperties(prefix = "fishing.api")
public record PublicApiProperties(String kmaServiceKey, String khoaServiceKey) {

    public PublicApiProperties {
        kmaServiceKey = kmaServiceKey == null ? "" : kmaServiceKey.trim();
        khoaServiceKey = khoaServiceKey == null ? "" : khoaServiceKey.trim();
    }

    public boolean hasKmaKey() {
        return !kmaServiceKey.isEmpty();
    }

    public boolean hasKhoaKey() {
        return !khoaServiceKey.isEmpty();
    }
}
