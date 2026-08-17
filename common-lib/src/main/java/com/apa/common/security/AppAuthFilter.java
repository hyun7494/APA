package com.apa.common.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

/**
 * {@code Authorization: Bearer ...} 를 읽어 SecurityContext 에 {@link AuthenticatedUser} 를 넣는다.
 * auth-service 의 {@code JwtAuthenticationFilter} 를 common-lib 으로 옮긴 것이다.
 *
 * <p><b>토큰이 없거나 상해도 통과시킨다.</b> APA 앱들은 조회 API 가 대부분 공개라
 * (낚시앱은 지수·게시판·도감 마스터가 비로그인 OK) 여기서 막으면 안 되고,
 * 인증이 필요한 경로는 각 앱 SecurityConfig 의 매처가 401 을 낸다.
 *
 * <p><b>스프링 빈으로 등록하지 않는다.</b> Filter 타입 빈은 시큐리티 체인과 별개로 서블릿
 * 필터 체인에도 자동 등록돼 두 번 끼어든다. 각 앱 SecurityConfig 에서 {@code new} 로 만들어
 * {@code addFilterBefore} 에 넘길 것.
 */
public class AppAuthFilter extends OncePerRequestFilter {

    private static final String HEADER = "Authorization";
    private static final String PREFIX = "Bearer ";

    private final JwtTokenProvider jwtTokenProvider;

    public AppAuthFilter(JwtTokenProvider jwtTokenProvider) {
        this.jwtTokenProvider = jwtTokenProvider;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {

        String header = request.getHeader(HEADER);
        if (header != null && header.startsWith(PREFIX)) {
            jwtTokenProvider.parse(header.substring(PREFIX.length()))
                    .ifPresent(user -> authenticate(user, request));
        }

        filterChain.doFilter(request, response);
    }

    private void authenticate(AuthenticatedUser user, HttpServletRequest request) {
        // 권한(ROLE)은 아직 쓰지 않는다. 빈 목록이라도 넘겨야 인증된 것으로 취급된다 — null 이면 미인증이다.
        var authentication = new UsernamePasswordAuthenticationToken(user, null, List.of());
        authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
        SecurityContextHolder.getContext().setAuthentication(authentication);
    }
}
