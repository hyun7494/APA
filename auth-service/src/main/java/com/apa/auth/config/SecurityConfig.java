package com.apa.auth.config;

import com.apa.common.security.AppAuthFilter;
import com.apa.common.security.JwtSecurityConfig;
import com.apa.common.security.JwtTokenProvider;
import jakarta.servlet.DispatcherType;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.HttpStatusEntryPoint;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

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
                // 브라우저에서 부르려면 필요하다. **`anyRequest().authenticated()` 보다 먼저 걸려야 한다** —
                // preflight(OPTIONS)에는 Authorization 헤더가 없어서, 인가까지 흘러가면 401 이 되고
                // 브라우저에는 그 401 이 아니라 "No 'Access-Control-Allow-Origin' header" 로 보인다.
                // Spring Security 가 CorsFilter 를 인가 필터 앞에 두고, preflight 는 거기서 끝난다.
                .cors(Customizer.withDefaults())
                .csrf(csrf -> csrf.disable())           // 1. CSRF 해제
                .formLogin(form -> form.disable())      // 2. 기본 로그인 페이지 해제
                .httpBasic(basic -> basic.disable())    // 3. Basic 인증 해제
                // formLogin·httpBasic 을 끄면 기본 진입점이 Http403ForbiddenEntryPoint 라
                // **자격증명이 없을 때 403 이 나간다.** 그건 "인증했지만 권한 없음"이라는 뜻이고,
                // 여기서 실제로 일어난 일은 "토큰이 없거나 만료됨"이라 401 이 맞다.
                // 지금은 /auth/logout 하나뿐이고 프론트가 그 실패를 삼켜서 티가 안 나지만,
                // 인증 엔드포인트가 하나만 더 붙거나 이쪽에 refresh 인터셉터가 걸리는 순간
                // 403 은 "만료 → 갱신" 경로를 조용히 건너뛴다. app-fishing 도 같은 이유로 401 로 못박았다.
                .exceptionHandling(e -> e.authenticationEntryPoint(
                        new HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED)))
                .authorizeHttpRequests(auth -> auth     // 4. URL 권한 설정
                        // 스프링 부트는 처리 못 한 예외를 sendError() 로 /error 에 다시 태운다.
                        // 그 ERROR 디스패치에는 인증 정보가 없어서, 아래 anyRequest().authenticated()
                        // 가 그것까지 잡으면 **모든 오류가 403 으로 둔갑한다** — 깨진 JSON 은 400 이
                        // 아니라 403, 없는 경로는 404 가 아니라 403, 그리고 무엇보다 서버가 500 을
                        // 내도 403 이라 원인을 볼 수 없다. app-fishing 은 anyRequest().permitAll()
                        // 이라 이 문제가 없었다.
                        .dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()
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

    /**
     * Flutter Web(`flutter run -d chrome`)은 매번 임의 포트로 뜨므로 localhost 전체를 패턴으로 연다.
     * 로컬 개발 전용 설정이다 — <b>배포 시에는 실제 도메인으로 좁힐 것.</b>
     *
     * <p>⚠️ {@code app-fishing} 의 {@code SecurityConfig} 에 <b>같은 설정이 하나 더 있다</b>
     * (앱이 두 서버를 각각 부르기 때문이다: 로그인은 :8081, 나머지는 :8086).
     * <b>좁힐 때 한쪽만 고치면 다른 쪽이 열린 채로 남는다</b> — 반드시 둘 다 볼 것.
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
