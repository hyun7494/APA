package com.apa.fishing.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.HttpStatusEntryPoint;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

/**
 * 비로그인 우선 원칙 — 조회는 전부 열고 {@code /fishing/me/**} 만 막는다.
 * auth-service의 SecurityConfig는 anyRequest().authenticated() 이므로 그대로 복사하면 안 된다
 * (앱 전체가 401 → 빈 화면).
 */
@Configuration
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .cors(Customizer.withDefaults())
            .csrf(csrf -> csrf.disable())
            .formLogin(form -> form.disable())
            .httpBasic(basic -> basic.disable())
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            // formLogin·httpBasic을 끄면 기본 진입점이 Http403ForbiddenEntryPoint라 비로그인에 403이 나간다.
            // 프론트는 401만 "로그인 안 됨"으로 삼키고(그 외는 rethrow), 토큰 갱신도 401 기준이라 401로 못박는다.
            .exceptionHandling(e -> e.authenticationEntryPoint(
                    new HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED)))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/fishing/me/**").authenticated()
                .requestMatchers(HttpMethod.POST, "/fishing/board/**").authenticated()
                .anyRequest().permitAll()      // 조회는 전부 공개
            );
        return http.build();
    }

    /**
     * Flutter Web(flutter run -d chrome)은 매번 임의 포트로 뜨므로 localhost 전체를 패턴으로 연다.
     * 로컬 개발 전용 설정이다 — 배포 시에는 실제 도메인으로 좁힐 것.
     */
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(List.of("http://localhost:*", "http://127.0.0.1:*"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
