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
                        // 가입·로그인·재발급은 토큰이 없는 상태에서 부르는 것이라 열려 있어야 한다.
                        // /auth/link/social 도 마찬가지다 — 비밀번호와 소셜 토큰을 함께 받아
                        // 그 자리에서 인증하므로, 들어올 때 들고 있는 토큰이 없다.
                        .requestMatchers("/auth/signup", "/auth/login", "/auth/login/email",
                                "/auth/link/social", "/auth/refresh", "/auth/dev-login").permitAll()
                        // 로그아웃은 다르다 — 누구의 토큰을 지울지 알아야 하므로 인증이 필요하다.
                        .requestMatchers("/auth/logout").authenticated()
                        .anyRequest().authenticated()
                )
                // 필터는 빈으로 두지 않는다 (AppAuthFilter 주석 참고) — 서블릿 체인에 중복 등록된다
                .addFilterBefore(new AppAuthFilter(jwtTokenProvider),
                        UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
