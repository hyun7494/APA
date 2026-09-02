package com.apa.fishing;

import com.apa.fishing.support.IntegrationTestBase;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 서비스 경계 — 이 저장소의 제 1 원칙이 실제로 성립하는지 본다.
 *
 * <p>app-fishing 은 auth-service 를 부르지 않는다. 사용자가 누구인지 아는 근거가
 * <b>JWT 하나뿐</b>이고, 탈퇴 같은 두 서비스에 걸친 일도 앱이 순서대로 두 번 부르는
 * 것으로 처리한다. 그 구조가 성립하려면 몇 가지가 동시에 맞아야 하는데, 어느 하나가
 * 어긋나도 <b>부팅은 멀쩡하고 로그인도 되는데 개인 화면만 전부 401</b> 이 된다.
 */
class ServiceBoundaryIT extends IntegrationTestBase {

    private static final long USER_ID = 4242L;
    private static final String NICKNAME = "낚시왕";

    // ───────────────────────────────────────────────────── 마이그레이션

    /**
     * 빈 DB 에서 마이그레이션이 끝까지 도는지 본다.
     *
     * <p>개발 노트북의 DB 는 <b>이미 다 적용된 상태</b>라, 중간 판이 깨져 있어도
     * 아무도 모른다. 새 환경에 처음 올릴 때만 드러나는 종류의 고장이다.
     */
    @Test
    @DisplayName("빈 DB 에서 마이그레이션이 전부 적용되고 시드가 들어온다")
    void migrationsApplyFromScratch() {
        String failed = queryString("""
                SELECT coalesce(string_agg(version, ', '), '없음')
                FROM fishing.flyway_schema_history WHERE success = false
                """);
        assertThat(failed).isEqualTo("없음");

        // 걷어낸 운세 표가 되살아나지 않았는지 (V17 이 지웠다).
        assertThat(countOf("fishing_spots")).isPositive();
        assertThat(tableExists("fishing_daily_fortune")).isFalse();
        assertThat(tableExists("fishing_user_zodiac")).isFalse();
    }

    // ───────────────────────────────────────────────────── 토큰

    /**
     * <b>이 검사가 두 서비스를 잇는 유일한 끈이다.</b>
     *
     * <p>토큰은 auth-service 가 만들고 여기서 검증한다. HS256 대칭키라 비밀값이 갈리는
     * 순간 앱의 개인 화면이 전부 401 이 되는데, 두 서비스가 각자 잘 뜨기 때문에
     * <b>어느 쪽 로그에도 오류가 안 남는다.</b>
     */
    @Test
    @DisplayName("auth 가 발급한 모양의 토큰을 그대로 받아들인다")
    void acceptsTokenMintedWithTheSharedSecret() throws Exception {
        mvc.perform(get("/fishing/me/collection")
                        .header("Authorization", "Bearer " + tokenFor(USER_ID, NICKNAME)))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("토큰이 없으면 개인 화면은 401, 조회는 그대로 공개다")
    void personalScreensRequireAToken() throws Exception {
        mvc.perform(get("/fishing/me/collection")).andExpect(status().isUnauthorized());
        mvc.perform(get("/fishing/me/catches")).andExpect(status().isUnauthorized());
        mvc.perform(delete("/fishing/me")).andExpect(status().isUnauthorized());

        // 목록·지수 조회는 비로그인도 봐야 한다 (기획서 5-5). 여기까지 막으면
        // 앱을 처음 연 사람에게 빈 화면만 보인다.
        mvc.perform(get("/fishing/board")).andExpect(status().isOk());
        mvc.perform(get("/fishing/spots")).andExpect(status().isOk());
        mvc.perform(get("/fishing/regions")).andExpect(status().isOk());
    }

    /**
     * 다른 비밀값으로 서명한 토큰은 남의 서버가 발급한 것이다.
     *
     * <p>이게 통과하면 <b>아무나 userId 를 골라 남의 계정으로 글을 쓸 수 있다.</b>
     */
    @Test
    @DisplayName("다른 비밀값으로 서명한 토큰은 거절한다")
    void rejectsTokenSignedWithAnotherSecret() throws Exception {
        String forged = com.apa.fishing.support.ForeignToken.signedWith(
                "completely-different-secret-key-of-sufficient-length", USER_ID, NICKNAME);

        mvc.perform(get("/fishing/me/collection")
                        .header("Authorization", "Bearer " + forged))
                .andExpect(status().isUnauthorized());
    }

    // ───────────────────────────────────────────────────── 글쓰기

    @Test
    @DisplayName("작성자는 본문이 아니라 토큰에서 온다 — 남의 이름으로 못 쓴다")
    void authorComesFromTheTokenNotTheBody() throws Exception {
        long postId = writePost(USER_ID, NICKNAME, "첫 글", "오늘 잘 나왔습니다");

        String author = queryString(
                "SELECT author_nickname FROM fishing.fishing_posts WHERE id = " + postId);
        assertThat(author).isEqualTo(NICKNAME);
    }

    @Test
    @DisplayName("글을 쓰면 공개 프로필에 활동으로 잡힌다")
    void postsShowUpOnThePublicProfile() throws Exception {
        writePost(USER_ID, NICKNAME, "첫 글", "본문");
        writePost(USER_ID, NICKNAME, "둘째 글", "본문");

        mvc.perform(get("/fishing/users/" + USER_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nickname").value(NICKNAME))
                .andExpect(jsonPath("$.postCount").value(2))
                .andExpect(jsonPath("$.recentPosts.length()").value(2));
    }

    // ───────────────────────────────────────────────────── 탈퇴

    /**
     * 탈퇴의 <b>fishing 쪽 절반</b>. 앱이 이걸 먼저 부르고 그 다음에
     * {@code DELETE /auth/me} 를 부른다 — 뒤집으면 토큰이 죽어 이 요청을 못 보낸다.
     *
     * <p>지우는 것과 가리는 것이 갈린다. 조과·인증샷은 본인만 보는 개인 기록이라 지우고,
     * 글·댓글은 <b>남기고 이름만 가린다</b> — 지우면 남의 대화에 구멍이 생긴다 (약관 12조 3항).
     */
    @Test
    @DisplayName("탈퇴하면 글은 남고 이름만 가려진다")
    void withdrawalMasksTheAuthorButKeepsThePost() throws Exception {
        long postId = writePost(USER_ID, NICKNAME, "남을 글", "이 글은 지워지지 않는다");

        mvc.perform(delete("/fishing/me")
                        .header("Authorization", "Bearer " + tokenFor(USER_ID, NICKNAME)))
                .andExpect(status().isNoContent());

        assertThat(countOf("fishing_posts")).isEqualTo(1);

        String masked = queryString(
                "SELECT author_nickname FROM fishing.fishing_posts WHERE id = " + postId);
        assertThat(masked)
                .startsWith("탈퇴한 사용자")
                // ★ 내부 순번을 그대로 쓰면 안 된다 — 사용자 수와 가입 순서가 드러난다.
                .doesNotContain(String.valueOf(USER_ID));
    }

    @Test
    @DisplayName("두 번 탈퇴해도 같다 — 앱이 중간에 실패하면 다시 누른다")
    void withdrawalIsIdempotent() throws Exception {
        writePost(USER_ID, NICKNAME, "글", "본문");
        String token = "Bearer " + tokenFor(USER_ID, NICKNAME);

        mvc.perform(delete("/fishing/me").header("Authorization", token))
                .andExpect(status().isNoContent());
        String first = queryString(
                "SELECT author_nickname FROM fishing.fishing_posts LIMIT 1");

        mvc.perform(delete("/fishing/me").header("Authorization", token))
                .andExpect(status().isNoContent());
        String second = queryString(
                "SELECT author_nickname FROM fishing.fishing_posts LIMIT 1");

        assertThat(second).isEqualTo(first);
    }

    @Test
    @DisplayName("가린 이름은 사용자마다 다르다 — 같으면 누가 누군지 섞인다")
    void maskedNamesDifferPerUser() throws Exception {
        writePost(USER_ID, NICKNAME, "내 글", "본문");
        writePost(USER_ID + 1, "다른사람", "남의 글", "본문");

        mvc.perform(delete("/fishing/me")
                .header("Authorization", "Bearer " + tokenFor(USER_ID, NICKNAME)));
        mvc.perform(delete("/fishing/me")
                .header("Authorization", "Bearer " + tokenFor(USER_ID + 1, "다른사람")));

        String mine = queryString(
                "SELECT author_nickname FROM fishing.fishing_posts WHERE user_id = " + USER_ID);
        String theirs = queryString(
                "SELECT author_nickname FROM fishing.fishing_posts WHERE user_id = " + (USER_ID + 1));

        assertThat(mine).isNotEqualTo(theirs);
    }

    // ───────────────────────────────────────────────────── 거들기

    private long writePost(long userId, String nickname, String title, String content)
            throws Exception {
        String body = mvc.perform(multipart("/fishing/board")
                        .param("category", "CATCH")
                        .param("title", title)
                        .param("content", content)
                        .header("Authorization", "Bearer " + tokenFor(userId, nickname)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(body).get("id").asLong();
    }

    private boolean tableExists(String name) {
        String found = queryString("""
                SELECT coalesce(max(table_name), 'none') FROM information_schema.tables
                WHERE table_schema = 'fishing' AND table_name = '%s'
                """.formatted(name));
        return !"none".equals(found);
    }
}
