package com.apa.auth.config;

import com.apa.common.security.AppAuthFilter;
import com.apa.common.security.JwtSecurityConfig;
import com.apa.common.security.JwtTokenProvider;
import jakarta.servlet.DispatcherType;
import org.springframework.beans.factory.annotation.Value;
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
                        // 헬스체크는 열어 둔다 — 도커·로드밸런서가 토큰 없이 부른다.
                        // ⚠️ `/actuator/**` 이 아니라 **health 만** 연다. 전부 열면
                        //    env·configprops 로 비밀값이 새어 나간다
                        //    (노출 자체도 application.yml 에서 health 로 좁혀 뒀다).
                        .requestMatchers("/actuator/health", "/actuator/health/**").permitAll()
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
     * 브라우저에서 부를 수 있는 출처.
     *
     * <p>기본값은 <b>로컬 개발용</b>이다 — Flutter Web(`flutter run -d chrome`)이 매번 임의
     * 포트로 떠서 localhost 전체를 패턴으로 연다.
     *
     * <p>⚠️ <b>배포에서는 {@code CORS_ALLOWED_ORIGINS} 로 실제 도메인만 넣을 것.</b>
     * 기본값을 그대로 두면 로컬에서 도는 아무 페이지나 이 API 를 부를 수 있다.
     * 쉼표로 여러 개를 준다: {@code https://app.example.com,https://www.example.com}
     */
    @Bean
    public CorsConfigurationSource corsConfigurationSource(
            @Value("${cors.allowed-origins:http://localhost:*,http://127.0.0.1:*}")
            List<String> allowedOrigins) {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(allowedOrigins);
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
