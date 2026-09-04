package com.apa.auth.support;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 진짜 Postgres 위에서 auth-service 를 통째로 띄운다.
 *
 * <p>★ <b>왜 필요한가.</b> 이 서비스에서 실제로 터진 것들은 단위 테스트가 볼 수 없는
 * 자리에 있었다 — 닉네임 UNIQUE 는 <b>DB 인덱스</b>고, 동의 실패 시 계정이 안 남는 것은
 * <b>트랜잭션</b>이고, 탈퇴가 이름을 잠그는 것은 <b>소프트 삭제 + 인덱스</b>의 합작이다.
 * 셋 다 H2 나 대역으로는 재현되지 않아서 그동안 실서버를 띄워 손으로 확인했다.
 *
 * <p>컨테이너는 <b>클래스마다 새로 띄우지 않고 JVM 당 하나</b>를 쓴다 (아래 static 블록).
 * Postgres 기동이 몇 초라 클래스마다 띄우면 그 시간이 그대로 쌓인다. 대신 테스트끼리
 * 데이터가 섞이므로 {@link #resetDatabase()} 가 매번 비운다.
 */
@Tag("integration")
@SpringBootTest
@AutoConfigureMockMvc
public abstract class IntegrationTestBase {

    private static final PostgreSQLContainer<?> POSTGRES =
            new PostgreSQLContainer<>("postgres:16")
                    .withDatabaseName("apa")
                    .withUsername("apa_user")
                    .withPassword("test-only-password")
                    // ⚠️ URL 뒤에 `?currentSchema=auth` 를 그냥 붙이면 안 된다 —
                    //    getJdbcUrl() 이 이미 쿼리 파라미터를 달고 나와서 `?` 가 둘이 되고,
                    //    그러면 통째로 무시된 채 public 스키마를 보게 된다. 증상은
                    //    "Schema-validation: missing table [refresh_tokens]" 라 원인이 잘 안 보인다.
                    .withUrlParam("currentSchema", "auth");

    static {
        POSTGRES.start();   // JVM 이 끝날 때 Ryuk 이 치운다. stop() 을 부르면 안 된다 —
                            // 다음 테스트 클래스가 꺼진 컨테이너를 물게 된다.
    }

    /**
     * ⚠️ <b>이 메서드가 개발 DB 를 지키는 자물쇠다.</b> 아래 {@code resetDatabase()} 가
     * 표를 통째로 비우기 때문에, 접속 주소가 컨테이너가 아니면 <b>노트북의 진짜 계정이
     * 날아간다.</b> 그래서 주소를 여기서 직접 박고, 매 테스트 전에 다시 확인한다.
     */
    @DynamicPropertySource
    static void datasource(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);

        // 32바이트 이상이어야 JwtProperties 검사를 통과한다 (RFC 7518 §3.2).
        registry.add("jwt.secret", () -> "integration-test-secret-key-32bytes-minimum-length");

        // 켜 두면 아무나 userId=1 토큰을 받는 스텁 경로가 열린다. 운영 기본값과 같게 둔다.
        registry.add("auth.dev-login-enabled", () -> "false");
    }

    @Autowired protected MockMvc mvc;

    /**
     * 시도 제한은 스프링 빈이라 <b>검사 사이에 상태가 남는다.</b> 비우지 않으면 무차별
     * 대입 검사가 걸어 둔 잠금 때문에 뒤 검사들이 429 로 죽는다 — 실제로 그렇게 깨졌다.
     */
    @Autowired private com.apa.auth.service.LoginAttemptGuard loginAttempts;
    @Autowired protected ObjectMapper json;
    @Autowired private JdbcTemplate jdbc;

    /**
     * 표를 비운다. 컨테이너를 공유하므로 앞 테스트가 만든 계정이 남으면 "이미 가입된
     * 이메일" 같은 엉뚱한 실패가 난다.
     *
     * <p>⚠️ {@code users} 를 먼저 지우면 FK 가 막는다 — 자식부터 지운다.
     * (운영에서 계정을 지울 일이 있을 때도 같은 순서다.)
     */
    @BeforeEach
    void resetLoginAttempts() {
        loginAttempts.clear();
    }

    @BeforeEach
    void resetDatabase() {
        String url = jdbc.execute((org.springframework.jdbc.core.ConnectionCallback<String>)
                c -> c.getMetaData().getURL());
        assertThat(url)
                .as("테스트 DB 가 컨테이너가 아니다 — 이대로 비우면 개발 DB 가 날아간다")
                .contains(String.valueOf(POSTGRES.getFirstMappedPort()));

        jdbc.execute("""
                TRUNCATE TABLE auth.refresh_tokens, auth.user_app_links,
                               auth.user_social_accounts, auth.user_consents,
                               auth.user_fcm_tokens, auth.users
                RESTART IDENTITY CASCADE
                """);
    }

    /** 표의 행 수. "계정이 안 만들어졌다" 같은 주장을 눈으로 확인하는 용도다. */
    protected int countOf(String table) {
        return jdbc.queryForObject("SELECT count(*) FROM auth." + table, Integer.class);
    }

    protected String jsonOf(Object body) throws Exception {
        return json.writeValueAsString(body);
    }
}
