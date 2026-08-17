package com.apa.auth.config;

import com.apa.common.security.AppAuthFilter;
import com.apa.common.security.JwtSecurityConfig;
import com.apa.common.security.JwtTokenProvider;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

/**
 * JWT 인증서버로 한 번 발급해서 여러 서비스에서 사용(MSA).
 *
 * <p>필터·토큰 검증은 common-lib 의 것을 쓴다 — 발급은 여기만, 검증은 모든 앱이.
 */
@Configuration
@Import(JwtSecurityConfig.class)
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http,
                                           JwtTokenProvider jwtTokenProvider) throws Exception {
        http
                .csrf(csrf -> csrf.disable())           // 1. CSRF 해제
                .formLogin(form -> form.disable())      // 2. 기본 로그인 페이지 해제
                .httpBasic(basic -> basic.disable())    // 3. Basic 인증 해제
                .authorizeHttpRequests(auth -> auth     // 4. URL 권한 설정
                        .requestMatchers("/auth/**").permitAll()
                        .anyRequest().authenticated()
                )
                // 필터는 빈으로 두지 않는다 (AppAuthFilter 주석 참고) — 서블릿 체인에 중복 등록된다
                .addFilterBefore(new AppAuthFilter(jwtTokenProvider),
                        UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
