package com.apa.fishing;

import com.apa.fishing.support.IntegrationTestBase;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.ResultActions;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 즐겨찾는 권역.
 *
 * <p>표는 {@code V1} 부터 있었는데 <b>넣는 길이 없어 행이 늘 0 이었다.</b> 그래서 화면에서
 * 칩·개수·메뉴를 걷어냈었다. 여기서 검사하는 것은 "쓰기가 된다" 만이 아니라,
 * <b>여러 번 눌러도 같은 결과가 되는지</b>다 — 그 성질 때문에 토글이 아니라 넣기/빼기로
 * 만들었으므로, 그게 무너지면 설계 근거가 사라진다.
 */
class FavoriteIT extends IntegrationTestBase {

    private static final long USER = 7001L;
    private static final String NICK = "즐겨찾는사람";

    /** V14 가 심은 권역. 동해 101 · 서해 102 · 남해 103 · 제주 104. */
    private static final long 동해 = 101L;
    private static final long 남해 = 103L;

    private ResultActions add(long userId, long regionId) throws Exception {
        return mvc.perform(put("/fishing/me/favorites/" + regionId)
                .header("Authorization", "Bearer " + tokenFor(userId, NICK)));
    }

    private ResultActions remove(long userId, long regionId) throws Exception {
        return mvc.perform(delete("/fishing/me/favorites/" + regionId)
                .header("Authorization", "Bearer " + tokenFor(userId, NICK)));
    }

    // ───────────────────────────────────────────────────── 기본

    @Test
    @DisplayName("넣으면 목록에 뜨고, 빼면 사라진다")
    void addAndRemove() throws Exception {
        mvc.perform(get("/fishing/me/favorites")
                        .header("Authorization", "Bearer " + tokenFor(USER, NICK)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));

        add(USER, 동해).andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].id").value(동해))
                .andExpect(jsonPath("$[0].name").value("동해"));

        add(USER, 남해).andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2));

        remove(USER, 동해).andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].id").value(남해));

        assertThat(countOf("fishing_user_favorites")).isEqualTo(1);
    }

    /**
     * ★ <b>이것 때문에 토글로 안 만들었다.</b>
     *
     * <p>토글이면 응답이 유실돼 앱이 재시도할 때 도로 꺼진다 — 사용자는 별을 한 번
     * 눌렀는데 결과가 두 번 누른 것이 된다. 넣기/빼기는 몇 번을 보내도 같다.
     */
    @Test
    @DisplayName("두 번 넣어도 하나, 두 번 빼도 오류가 아니다")
    void writesAreIdempotent() throws Exception {
        add(USER, 동해).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1));
        add(USER, 동해).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(1));
        assertThat(countOf("fishing_user_favorites")).isEqualTo(1);

        remove(USER, 동해).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
        remove(USER, 동해).andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
        assertThat(countOf("fishing_user_favorites")).isZero();
    }

    // ───────────────────────────────────────────────────── 경계

    /**
     * ⚠️ 없는 권역을 그냥 저장하면 FK 위반이 <b>500</b> 으로 나간다 — 사용자에게는 서버가
     * 고장 난 것처럼 보이지만 실은 잘못된 요청이다.
     *
     * <p>실제로 일어날 수 있다. V14 가 권역을 갈아엎으면서 옛 id 가 사라졌고, 그때 열려
     * 있던 앱은 없는 id 를 들고 있었다.
     */
    @Test
    @DisplayName("없는 권역은 404 다 — 500 이 아니라")
    void unknownRegionIsNotFound() throws Exception {
        add(USER, 99999L).andExpect(status().isNotFound());
        remove(USER, 99999L).andExpect(status().isNotFound());
        assertThat(countOf("fishing_user_favorites")).isZero();
    }

    @Test
    @DisplayName("남의 즐겨찾기는 안 보이고 안 건드려진다")
    void favoritesArePerUser() throws Exception {
        add(USER, 동해);
        add(USER + 1, 남해);

        mvc.perform(get("/fishing/me/favorites")
                        .header("Authorization", "Bearer " + tokenFor(USER, NICK)))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].id").value(동해));

        // 남의 것을 지우려 해도 내 것만 지워진다 — userId 는 토큰에서 오지 경로에서 오지 않는다.
        remove(USER, 남해).andExpect(status().isOk());
        assertThat(countOf("fishing_user_favorites")).isEqualTo(2);
    }

    @Test
    @DisplayName("토큰이 없으면 전부 401 이다")
    void requiresAuth() throws Exception {
        mvc.perform(get("/fishing/me/favorites")).andExpect(status().isUnauthorized());
        mvc.perform(put("/fishing/me/favorites/" + 동해)).andExpect(status().isUnauthorized());
        mvc.perform(delete("/fishing/me/favorites/" + 동해)).andExpect(status().isUnauthorized());
    }

    // ───────────────────────────────────────────────────── 다른 화면과의 연결

    @Test
    @DisplayName("마이페이지의 개수와 칩이 함께 따라온다")
    void profileReflectsFavorites() throws Exception {
        add(USER, 동해);
        add(USER, 남해);

        mvc.perform(get("/fishing/me/profile")
                        .header("Authorization", "Bearer " + tokenFor(USER, NICK)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.favoriteCount").value(2))
                .andExpect(jsonPath("$.favoriteRegions.length()").value(2));
    }

    /**
     * 탈퇴하면 즐겨찾기는 <b>지운다</b> (계약서 "좋아요·즐겨찾기 → 삭제").
     * 집계용이고 이름이 안 붙어서, 글처럼 남겨 둘 이유가 없다.
     */
    @Test
    @DisplayName("탈퇴하면 즐겨찾기가 지워진다")
    void withdrawalClearsFavorites() throws Exception {
        add(USER, 동해);
        add(USER, 남해);

        mvc.perform(delete("/fishing/me")
                        .header("Authorization", "Bearer " + tokenFor(USER, NICK)))
                .andExpect(status().isNoContent());

        assertThat(countOf("fishing_user_favorites")).isZero();
    }
}
