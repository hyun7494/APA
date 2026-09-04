package com.apa.fishing;

import com.apa.fishing.support.IntegrationTestBase;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

import java.util.Base64;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 사진의 <b>공개 범위</b>가 실제로 지켜지는가.
 *
 * <p>★ <b>여기 있는 것은 실제로 뚫렸던 구멍이다.</b> 조과 인증샷(본인만)과 게시글 사진
 * (누구나)을 한 폴더에 저장하고 접근 정책을 URL 앞부분으로만 갈랐더니, <b>같은 파일을
 * 게시판 경로로 요청하면 토큰 없이 그대로 내려왔다.</b> 소유자 확인이 걸린 경로에서는
 * 401·404 인 바로 그 파일이었다.
 *
 * <p>이제 폴더가 경계라 게시판 요청은 조과 폴더를 볼 수 없다 ({@code PhotoScope}).
 * 그 경계가 무너지면 여기서 걸린다.
 */
class PhotoAccessIT extends IntegrationTestBase {

    private static final long OWNER = 9001L;
    private static final long STRANGER = 9002L;

    /** 1x1 PNG. ImageIO 가 실제로 디코딩할 수 있어야 저장까지 간다. */
    private static final byte[] PNG = Base64.getDecoder().decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==");

    private String bearer(long userId) {
        return "Bearer " + tokenFor(userId, "사진주인" + userId);
    }

    /** 조과를 등록하고 그 인증샷의 파일명을 돌려준다. */
    private String uploadCatchPhoto() throws Exception {
        String body = mvc.perform(multipart("/fishing/me/catches")
                        .file(new MockMultipartFile("photos", "secret.png", "image/png", PNG))
                        .param("speciesId", "1")
                        .param("lengthCm", "42")
                        .param("caughtAt", "2026-09-03")
                        .header("Authorization", bearer(OWNER)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        String url = json.readTree(body).path("record").path("photoUrls").get(0).asText();
        assertThat(url).startsWith("/fishing/me/photos/");
        return url.substring(url.lastIndexOf('/') + 1);
    }

    /** 글에 사진을 붙이고 그 파일명을 돌려준다. */
    private String uploadBoardPhoto() throws Exception {
        String body = mvc.perform(multipart("/fishing/board")
                        .file(new MockMultipartFile("photo", "open.png", "image/png", PNG))
                        .param("category", "CATCH")
                        .param("title", "사진 붙인 글")
                        .param("content", "본문")
                        .header("Authorization", bearer(OWNER)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();

        String url = json.readTree(body).path("photoUrl").asText();
        assertThat(url).startsWith("/fishing/board/photos/");
        return url.substring(url.lastIndexOf('/') + 1);
    }

    // ───────────────────────────────────────────────────── 비공개 사진

    /**
     * ★ <b>이 검사가 이 파일의 존재 이유다.</b>
     *
     * <p>세 경로가 같은 파일을 가리켰고, 앞의 둘만 막혔다. 셋째가 200 을 주는 순간
     * 앞의 두 검사는 아무 의미가 없다 — 우회로가 하나만 있으면 되기 때문이다.
     */
    @Test
    @DisplayName("★ 조과 인증샷은 게시판 경로로 우회해서 꺼낼 수 없다")
    void privatePhotoIsNotReachableThroughThePublicPath() throws Exception {
        String fileName = uploadCatchPhoto();

        // ⓐ 주인은 볼 수 있다.
        mvc.perform(get("/fishing/me/photos/" + fileName).header("Authorization", bearer(OWNER)))
                .andExpect(status().isOk());

        // ⓑ 토큰이 없으면 401.
        mvc.perform(get("/fishing/me/photos/" + fileName))
                .andExpect(status().isUnauthorized());

        // ⓒ 남의 토큰이면 404 (403 과 가르지 않는다 — 존재를 알려주는 셈이다).
        mvc.perform(get("/fishing/me/photos/" + fileName).header("Authorization", bearer(STRANGER)))
                .andExpect(status().isNotFound());

        // ⓓ ★ 인증 없는 게시판 경로로 같은 파일명 — 여기가 뚫렸던 자리다.
        mvc.perform(get("/fishing/board/photos/" + fileName))
                .andExpect(status().isNotFound());

        // ⓔ 썸네일도 마찬가지다. 원본만 막고 썸네일을 열어 두면 사진은 그대로 새어 나간다.
        mvc.perform(get("/fishing/board/photos/" + fileName).param("thumb", "true"))
                .andExpect(status().isNotFound());
    }

    // ───────────────────────────────────────────────────── 공개 사진

    @Test
    @DisplayName("게시글 사진은 비로그인도 볼 수 있어야 한다 — 막으면 글의 사진이 다 깨진다")
    void boardPhotoStaysPublic() throws Exception {
        String fileName = uploadBoardPhoto();

        mvc.perform(get("/fishing/board/photos/" + fileName)).andExpect(status().isOk());
        mvc.perform(get("/fishing/board/photos/" + fileName).param("thumb", "true"))
                .andExpect(status().isOk());
    }

    /**
     * 반대 방향도 막혀 있어야 한다.
     *
     * <p>게시글 사진을 조과 경로로 부르면 소유자 확인에 걸려 404 다. 우회가 아니라
     * <b>범위가 갈렸다는 것</b>을 양쪽에서 확인하는 것이다.
     */
    @Test
    @DisplayName("게시글 사진은 조과 경로로도 안 열린다")
    void boardPhotoIsNotReachableThroughThePrivatePath() throws Exception {
        String fileName = uploadBoardPhoto();

        mvc.perform(get("/fishing/me/photos/" + fileName).header("Authorization", bearer(OWNER)))
                .andExpect(status().isNotFound());
    }

    // ───────────────────────────────────────────────────── 삭제

    /**
     * ★ <b>지운 글의 사진이 디스크에 남아 계속 열렸다.</b>
     *
     * <p>파일명을 벗겨내는 코드가 조과 경로만 알아서, 게시글 사진을 지우라고 하면 null 이
     * 나와 조용히 되돌아갔다. 글은 사라지는데 사진은 공개 URL 로 영원히 남는 상태였다.
     */
    @Test
    @DisplayName("★ 글을 지우면 사진 파일도 사라진다 — 공개 URL 이 남으면 안 된다")
    void deletingAPostRemovesItsPhoto() throws Exception {
        String body = mvc.perform(multipart("/fishing/board")
                        .file(new MockMultipartFile("photo", "open.png", "image/png", PNG))
                        .param("category", "CATCH")
                        .param("title", "지울 글")
                        .param("content", "본문")
                        .header("Authorization", bearer(OWNER)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();

        long postId = json.readTree(body).path("id").asLong();
        String url = json.readTree(body).path("photoUrl").asText();
        String fileName = url.substring(url.lastIndexOf('/') + 1);

        mvc.perform(get("/fishing/board/photos/" + fileName)).andExpect(status().isOk());

        mvc.perform(delete("/fishing/board/" + postId).header("Authorization", bearer(OWNER)))
                .andExpect(status().isNoContent());

        mvc.perform(get("/fishing/board/photos/" + fileName)).andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("탈퇴하면 인증샷 파일도 사라진다")
    void withdrawalRemovesCatchPhotos() throws Exception {
        String fileName = uploadCatchPhoto();

        mvc.perform(get("/fishing/me/photos/" + fileName).header("Authorization", bearer(OWNER)))
                .andExpect(status().isOk());

        mvc.perform(delete("/fishing/me").header("Authorization", bearer(OWNER)))
                .andExpect(status().isNoContent());

        mvc.perform(get("/fishing/me/photos/" + fileName).header("Authorization", bearer(OWNER)))
                .andExpect(status().isNotFound());
    }
}
