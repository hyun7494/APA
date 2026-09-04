package com.apa.auth;

import com.apa.auth.support.IntegrationTestBase;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 계정의 한살이 — 가입 · 동의 · 로그인 · 탈퇴.
 *
 * <p>여기 있는 것은 전부 <b>지금까지 실서버를 띄워 손으로 확인하던</b> 것들이다.
 * 하나하나가 과거에 실제로 뚫렸거나 뚫릴 뻔했던 자리라, 다시 뚫리면 여기서 걸린다.
 */
class AccountLifecycleIT extends IntegrationTestBase {

    private static final String TERMS = "TERMS_OF_SERVICE";
    private static final String PRIVACY = "PRIVACY_POLICY";
    private static final String AGE = "AGE_14";
    private static final String MARKETING = "MARKETING";

    private static Map<String, Object> consent(String type, boolean agreed) {
        return Map.of("type", type, "agreed", agreed, "version", "1.0");
    }

    private static List<Map<String, Object>> allRequired() {
        return List.of(consent(TERMS, true), consent(PRIVACY, true), consent(AGE, true));
    }

    private Map<String, Object> signUpBody(String email, String nickname,
                                           List<Map<String, Object>> consents) {
        return Map.of("email", email, "password", "hyun1234!", "nickname", nickname,
                "appId", "fishing", "consents", consents);
    }

    private void signUpOk(String email, String nickname) throws Exception {
        mvc.perform(post("/auth/signup").contentType("application/json")
                        .content(jsonOf(signUpBody(email, nickname, allRequired()))))
                .andExpect(status().isCreated());
    }

    // ───────────────────────────────────────────────────── 가입과 동의

    @Test
    @DisplayName("가입하면 토큰이 나오고, 동의가 항목마다 한 행씩 남는다")
    void signUpRecordsEveryConsent() throws Exception {
        var body = signUpBody("angler@example.com", "바다사랑",
                List.of(consent(TERMS, true), consent(PRIVACY, true), consent(AGE, true),
                        consent(MARKETING, false)));

        mvc.perform(post("/auth/signup").contentType("application/json").content(jsonOf(body)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty());

        // 거부한 선택 항목도 행으로 남아야 한다 — "묻지 않았다" 와 "물었고 거절했다" 는
        // 다른 사실이고, 나중에 마케팅을 보낼 때 그 둘을 구별할 수 있어야 한다.
        assertThat(countOf("user_consents")).isEqualTo(4);
    }

    @Nested
    @DisplayName("필수 동의를 안 하면")
    class RequiredConsentMissing {

        /**
         * <b>400 만으로는 부족하다. 계정이 남지 않아야 한다.</b>
         *
         * <p>동의 기록은 계정을 만든 <i>뒤에</i> 같은 트랜잭션 안에서 남는다. 롤백이
         * 안 걸리면 <b>동의 없는 계정</b>이 조용히 쌓이는데, 그건 응답만 봐서는 절대
         * 알 수 없다 — 사용자에게는 똑같이 400 이 간다.
         */
        @Test
        @DisplayName("계정이 하나도 안 남는다 (트랜잭션 롤백)")
        void leavesNoAccount() throws Exception {
            List<List<Map<String, Object>>> cases = List.of(
                    List.of(consent(PRIVACY, true), consent(AGE, true)),
                    List.of(consent(TERMS, true), consent(AGE, true)),
                    List.of(consent(TERMS, true), consent(PRIVACY, true)),
                    List.of(consent(TERMS, false), consent(PRIVACY, true), consent(AGE, true)),
                    List.of());

            for (List<Map<String, Object>> consents : cases) {
                mvc.perform(post("/auth/signup").contentType("application/json")
                                .content(jsonOf(signUpBody("ghost@example.com", "유령", consents))))
                        .andExpect(status().isBadRequest());
            }

            assertThat(countOf("users")).isZero();
            assertThat(countOf("user_consents")).isZero();
        }

        @Test
        @DisplayName("판(version)이 없으면 거절한다 — 뭐에 동의했는지 잃는다")
        void requiresVersion() throws Exception {
            List<Map<String, Object>> noVersion = List.of(
                    Map.of("type", TERMS, "agreed", true),
                    consent(PRIVACY, true), consent(AGE, true));

            mvc.perform(post("/auth/signup").contentType("application/json")
                            .content(jsonOf(signUpBody("v@example.com", "판없음", noVersion))))
                    .andExpect(status().isBadRequest());

            assertThat(countOf("users")).isZero();
        }
    }

    @Test
    @DisplayName("선택 항목은 거부해도 가입된다 — 조건으로 걸면 동의가 아니라 강요다")
    void optionalConsentNeverBlocksSignUp() throws Exception {
        var body = signUpBody("nomarketing@example.com", "광고싫어",
                List.of(consent(TERMS, true), consent(PRIVACY, true), consent(AGE, true),
                        consent(MARKETING, false)));

        mvc.perform(post("/auth/signup").contentType("application/json").content(jsonOf(body)))
                .andExpect(status().isCreated());
    }

    // ───────────────────────────────────────────────────── 닉네임

    /**
     * 이 검사가 <b>DB 인덱스</b>({@code uq_users_nickname_lower})를 본다. 자바 쪽 사전
     * 조회는 통과시키고 인덱스만 막는 경우가 있어서, 진짜 Postgres 가 아니면 의미가 없다.
     */
    @Test
    @DisplayName("대소문자만 다른 닉네임도 중복이다")
    void nicknameIsCaseInsensitive() throws Exception {
        signUpOk("first@example.com", "Bada");

        mvc.perform(post("/auth/signup").contentType("application/json")
                        .content(jsonOf(signUpBody("second@example.com", "bada", allRequired()))))
                .andExpect(status().isConflict());

        assertThat(countOf("users")).isEqualTo(1);
    }

    @Test
    @DisplayName("닉네임을 안 적으면 이메일 앞부분으로 지어 주고, 겹치면 숫자를 붙인다")
    void generatesNicknameWhenBlank() throws Exception {
        for (String domain : List.of("a.com", "b.com", "c.com")) {
            var body = Map.of("email", "hong@" + domain, "password", "hyun1234!",
                    "appId", "fishing", "consents", allRequired());
            mvc.perform(post("/auth/signup").contentType("application/json").content(jsonOf(body)))
                    .andExpect(status().isCreated());
        }

        // 물어볼 화면이 없는 자리라 409 로 되묻지 않고 알아서 비켜 간다.
        assertThat(countOf("users")).isEqualTo(3);
    }

    // ───────────────────────────────────────────────────── 탈퇴

    /**
     * <b>이 프로젝트에서 가장 조용히 깨질 수 있는 규칙.</b>
     *
     * <p>탈퇴가 소프트 삭제라서 행이 남고, 행이 남으니 UNIQUE 인덱스가 떠난 사람의
     * 이름을 계속 붙잡는다. 게시글에 박힌 작성자 이름(스냅샷)이 어긋나지 않는 근거가
     * 전부 여기에 걸려 있다.
     *
     * <p>누군가 탈퇴를 <b>하드 삭제로 바꾸는 순간</b> 이름이 풀리고, 남이 그 이름을
     * 가져가면 옛 글이 그 사람 것처럼 보인다. 코드만 봐서는 안 드러나는 연결이라
     * 이 테스트가 그걸 지킨다.
     */
    @Test
    @DisplayName("탈퇴해도 닉네임은 영구히 잠긴다")
    void withdrawalLocksNicknameForever() throws Exception {
        signUpOk("leaving@example.com", "떠나는사람");
        String token = loginToken("leaving@example.com");

        mvc.perform(delete("/auth/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        // 행이 남아 있어야 인덱스가 이름을 붙잡는다.
        assertThat(countOf("users")).isEqualTo(1);

        mvc.perform(post("/auth/signup").contentType("application/json")
                        .content(jsonOf(signUpBody("newbie@example.com", "떠나는사람", allRequired()))))
                .andExpect(status().isConflict());
    }

    @Test
    @DisplayName("탈퇴하면 로그인은 막히지만, 같은 이메일로 새로 가입은 된다")
    void withdrawnUserCannotLoginButMayReturn() throws Exception {
        signUpOk("comeback@example.com", "돌아올사람");
        String token = loginToken("comeback@example.com");

        mvc.perform(delete("/auth/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mvc.perform(post("/auth/login/email").contentType("application/json")
                        .content(jsonOf(Map.of("email", "comeback@example.com",
                                "password", "hyun1234!", "appId", "fishing"))))
                .andExpect(status().isUnauthorized());

        // 이메일·비밀번호를 파기했으므로 같은 주소가 다시 비어 있다 (별개의 새 계정).
        mvc.perform(post("/auth/signup").contentType("application/json")
                        .content(jsonOf(signUpBody("comeback@example.com", "새이름", allRequired()))))
                .andExpect(status().isCreated());

        assertThat(countOf("users")).isEqualTo(2);
    }

    @Test
    @DisplayName("탈퇴를 두 번 불러도 조용히 통과한다 — 앱이 중간에 실패하면 다시 누른다")
    void withdrawalIsIdempotent() throws Exception {
        signUpOk("twice@example.com", "두번");
        String token = loginToken("twice@example.com");

        mvc.perform(delete("/auth/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());
        mvc.perform(delete("/auth/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());
    }

    @Test
    @DisplayName("탈퇴해도 동의 기록은 남는다 — 동의를 받았다는 증빙")
    void consentRecordsSurviveWithdrawal() throws Exception {
        signUpOk("proof@example.com", "증빙");
        String token = loginToken("proof@example.com");

        mvc.perform(delete("/auth/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        assertThat(countOf("user_consents")).isEqualTo(3);
    }

    // ───────────────────────────────────────────────────── 로그인

    @Test
    @DisplayName("없는 계정과 틀린 비밀번호가 같은 문구로 실패한다")
    void loginFailureDoesNotRevealWhoIsRegistered() throws Exception {
        signUpOk("real@example.com", "실제계정");

        String wrongPassword = failureDetail("real@example.com", "틀린비번1!");
        String noSuchUser = failureDetail("nobody@example.com", "hyun1234!");

        // 문구가 갈리면 그것만으로 어떤 주소가 가입돼 있는지 훑어볼 수 있다.
        assertThat(wrongPassword).isEqualTo(noSuchUser);
    }

    /**
     * ★ <b>아무 제한도 없었다.</b> 틀린 비밀번호로 60번을 연속으로 넣어도 전부 401 이고
     * 잠금도 지연도 없었으며, 그 뒤 맞는 비밀번호가 그대로 통했다.
     *
     * <p>여기서 보는 것은 "몇 번 만에 막히나" 가 아니라 <b>언젠가 막히기는 하는가</b>다.
     * 한도(기본 10)를 조정해도 이 검사는 살아 있어야 한다.
     */
    @Test
    @DisplayName("★ 틀린 비밀번호를 계속 넣으면 결국 막힌다 (429)")
    void repeatedFailuresGetRateLimited() throws Exception {
        signUpOk("brute@example.com", "무차별대상");

        int limited = 0;
        for (int i = 0; i < 30; i++) {
            var result = mvc.perform(post("/auth/login/email").contentType("application/json")
                            .content(jsonOf(Map.of("email", "brute@example.com",
                                    "password", "틀린비번" + i, "appId", "fishing"))))
                    .andReturn();
            if (result.getResponse().getStatus() == 429) {
                limited++;
            }
        }
        assertThat(limited)
                .as("30번을 틀렸는데 한 번도 안 막혔다 — 무차별 대입을 그대로 받는다")
                .isPositive();

        // ⚠️ **맞는 비밀번호도 잠긴 동안에는 막힌다.** 그게 잠금의 뜻이다 —
        //    여기서 통과시키면 공격자는 맞힌 순간 들어가므로 막은 의미가 없다.
        mvc.perform(post("/auth/login/email").contentType("application/json")
                        .content(jsonOf(Map.of("email", "brute@example.com",
                                "password", "hyun1234!", "appId", "fishing"))))
                .andExpect(status().isTooManyRequests());
    }

    @Test
    @DisplayName("흔한 비밀번호로는 가입할 수 없다")
    void rejectsCommonPasswordAtSignUp() throws Exception {
        var body = Map.of("email", "weak@example.com", "password", "12345678",
                "nickname", "약한비번", "appId", "fishing", "consents", allRequired());

        mvc.perform(post("/auth/signup").contentType("application/json").content(jsonOf(body)))
                .andExpect(status().isBadRequest());

        assertThat(countOf("users")).isZero();
    }

    @Test
    @DisplayName("dev-login 은 꺼져 있다 — 켜지면 누구나 userId=1 토큰을 받는다")
    void devLoginIsOffByDefault() throws Exception {
        mvc.perform(post("/auth/dev-login").contentType("application/json")
                        .content(jsonOf(Map.of("username", "testuser", "password", "hyun1234"))))
                .andExpect(status().is4xxClientError());
    }

    // ───────────────────────────────────────────────────── 거들기

    private String loginToken(String email) throws Exception {
        String body = mvc.perform(post("/auth/login/email").contentType("application/json")
                        .content(jsonOf(Map.of("email", email, "password", "hyun1234!",
                                "appId", "fishing"))))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(body).get("accessToken").asText();
    }

    /**
     * 401 의 안내 문구를 꺼낸다.
     *
     * <p>이 서비스는 401 만 <b>ProblemDetail 이 아니라 맨 문자열</b>로 내려준다
     * ({@code GlobalExceptionHandler.handleUnauthorized}). 나머지 오류는 전부 JSON 이라
     * 모양이 갈리는데, 프론트가 두 경우를 다 받아내고 있어서 사용자에게 닿는 문구는
     * 멀쩡하다 ({@code auth_repository.dart} 의 {@code _serverMessage}).
     *
     * <p>여기서 굳이 두 모양을 다 읽는 이유 — 나중에 저 핸들러를 ProblemDetail 로
     * 맞추더라도 이 테스트가 <b>엉뚱하게 깨지지 않게</b> 하려는 것이다. 검사하려는 건
     * 응답의 모양이 아니라 <b>두 실패가 같은 문구를 쓴다</b>는 사실이다.
     */
    private String failureDetail(String email, String password) throws Exception {
        String body = mvc.perform(post("/auth/login/email").contentType("application/json")
                        .content(jsonOf(Map.of("email", email, "password", password,
                                "appId", "fishing"))))
                .andExpect(status().isUnauthorized())
                .andReturn().getResponse().getContentAsString();

        if (body.startsWith("{")) {
            return json.readTree(body).path("detail").asText();
        }
        return body;
    }
}
