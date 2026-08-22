package com.apa.auth.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * 비밀번호 해시.
 *
 * <p>BCrypt 다 — 느리게 설계된 해시라 유출돼도 대입 공격이 실용적이지 않다.
 * SHA-256 같은 범용 해시는 초당 수억 번 시도할 수 있어 비밀번호에 쓰면 안 된다
 * (리프레시 토큰은 다르다. 그쪽은 우리가 만든 128비트 난수라 대입할 것이 없다 —
 * {@code TokenHash} 참고).
 */
@Configuration
public class PasswordConfig {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
