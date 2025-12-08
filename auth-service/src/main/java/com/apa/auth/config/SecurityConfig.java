package com.apa.auth.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.security.web.SecurityFilterChain;

import com.apa.auth.security.JwtAuthenticationFilter;


@Configuration
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http,
                                           JwtAuthenticationFilter jwtFilter) throws Exception {
        // JWT 인증서버로 한 번 발급해서 여러 서비스에서 사용(MSA)
        http
                .csrf(csrf -> csrf.disable())           // 1. CSRF 해제
                .formLogin(form -> form.disable())      // 2. 기본 로그인 페이지 해제
                .httpBasic(basic -> basic.disable())    // 3. Basic 인증 해제
                .authorizeHttpRequests(auth -> auth     // 4. URL 권한 설정
                        .requestMatchers("/auth/**").permitAll()
                        .anyRequest().authenticated()
                )
                .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
