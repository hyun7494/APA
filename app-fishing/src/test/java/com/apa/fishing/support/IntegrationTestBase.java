package com.apa.fishing.support;

import com.apa.common.security.JwtTokenProvider;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 진짜 Postgres 위에서 app-fishing 을 통째로 띄운다.
 *
 * <p>auth-service 쪽 같은 이름의 클래스와 짝이다. 두 서비스가 <b>서로를 모르는</b> 구조라
 * 테스트 기반도 각자 갖는다 — 하나로 합치면 그 경계가 코드에서 흐려진다.
 *
 * <p>여기서는 <b>토큰을 직접 만들어 쓴다.</b> app-fishing 은 auth-service 를 부르지 않고
 * JWT 만 보고 사용자를 아는데, 그 "만 보고" 가 실제로 성립하는지가 검사 대상이다.
 * 같은 비밀값으로 서명한 토큰을 받아들이면 두 서비스의 계약이 맞는 것이고, 그게
 * 깨지면 로그인은 되는데 앱의 모든 개인 화면이 401 이 된다.
 */
@Tag("integration")
@SpringBootTest
@AutoConfigureMockMvc
public abstract class IntegrationTestBase {

    /**
     * auth-service 와 <b>같은 값을 쓴다</b>. HS256 대칭키라 발급과 검증이 키를 공유해야
     * 한다 — 값이 갈리면 여기서 401 이 난다.
     */
    protected static final String JWT_SECRET = "integration-test-secret-key-32bytes-minimum-length";

    private static final PostgreSQLContainer<?> POSTGRES =
            new PostgreSQLContainer<>("postgres:16")
                    .withDatabaseName("apa")
                    .withUsername("apa_user")
                    .withPassword("test-only-password")
                    // ⚠️ URL 에 `?currentSchema=fishing` 을 문자열로 붙이면 안 된다 —
                    //    getJdbcUrl() 이 이미 쿼리 파라미터를 달고 나와 `?` 가 둘이 되고,
                    //    그러면 통째로 무시된 채 public 스키마를 보게 된다.
                    .withUrlParam("currentSchema", "fishing");

    static {
        POSTGRES.start();
    }

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
        registry.add("jwt.secret", () -> JWT_SECRET);

        // 탈퇴자 꼬리표의 소금. 기본값이 없어 부팅이 실패하므로 테스트도 줘야 한다
        // (그 기본값이 저장소에 박혀 있던 것이 취약점이었다 — WithdrawnName 주석 참고).
        registry.add("fishing.withdrawn.secret", () -> "integration-test-withdrawn-secret");

        // ⚠️ 공공 API 키를 **비워 둔다.** 있으면 부팅 직후 지수 배치가 51곳 × 외부 API 를
        //    때리기 시작한다 (약 60초). 테스트가 남의 서버에 의존하면 안 되고, 무엇보다
        //    기상청이 느린 날 테스트가 덩달아 느려진다. 배치는 키가 없으면 스스로 건너뛴다.
        registry.add("fishing.api.kma-service-key", () -> "");
        registry.add("fishing.api.khoa-service-key", () -> "");
    }

    @Autowired protected MockMvc mvc;
    @Autowired protected ObjectMapper json;
    @Autowired protected JwtTokenProvider jwt;
    @Autowired private JdbcTemplate jdbc;

    /**
     * 사용자가 만든 것만 비운다.
     *
     * <p>⚠️ {@code fishing_spots}·{@code fishing_species}·{@code fishing_regions} 는
     * <b>건드리지 않는다</b> — 마이그레이션이 심은 시드(포인트 51곳·어종·권역)라
     * 지우면 뒤 테스트가 통째로 무너지고, 컨테이너를 새로 띄우기 전에는 안 돌아온다.
     */
    @BeforeEach
    void resetUserData() {
        String url = jdbc.execute((ConnectionCallback<String>) c -> c.getMetaData().getURL());
        assertThat(url)
                .as("테스트 DB 가 컨테이너가 아니다 — 이대로 비우면 개발 DB 가 날아간다")
                .contains(String.valueOf(POSTGRES.getFirstMappedPort()));

        jdbc.execute("""
                TRUNCATE TABLE fishing.fishing_post_likes, fishing.fishing_post_reports,
                               fishing.fishing_post_comments, fishing.fishing_posts,
                               fishing.fishing_catch_photos, fishing.fishing_user_catches,
                               fishing.fishing_user_favorites
                RESTART IDENTITY CASCADE
                """);
    }

    /** 그 사용자로 로그인한 셈 치는 토큰. auth-service 가 발급하는 것과 같은 모양이다. */
    protected String tokenFor(long userId, String nickname) {
        return jwt.createToken(userId, nickname);
    }

    protected int countOf(String table) {
        return jdbc.queryForObject("SELECT count(*) FROM fishing." + table, Integer.class);
    }

    protected String queryString(String sql) {
        return jdbc.queryForObject(sql, String.class);
    }
}
