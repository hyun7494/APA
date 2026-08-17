package com.apa.common.security;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * JWT 지원을 켜는 스위치. 각 앱은 SecurityConfig 에 {@code @Import(JwtSecurityConfig.class)} 만 붙이면 된다.
 *
 * <p>컴포넌트 스캔에 기대지 않는 이유: 앱들의 스캔 기준 패키지가 {@code com.apa.fishing} 처럼
 * 각자 달라 {@code com.apa.common} 은 애초에 안 잡힌다. 스캔 범위를 {@code com.apa} 로 넓히면
 * 다른 앱의 빈까지 딸려 들어올 여지가 생기므로 <b>필요한 앱이 명시적으로 Import</b> 하게 둔다.
 *
 * <p>{@link AppAuthFilter} 는 일부러 빈으로 만들지 않는다 — 이유는 그쪽 주석 참고.
 */
@Configuration
@EnableConfigurationProperties(JwtProperties.class)
public class JwtSecurityConfig {

    @Bean
    public JwtTokenProvider jwtTokenProvider(JwtProperties properties) {
        return new JwtTokenProvider(properties);
    }
}
