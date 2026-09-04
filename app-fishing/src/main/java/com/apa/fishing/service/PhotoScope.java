package com.apa.fishing.service;

/**
 * 사진의 <b>공개 범위</b>. 폴더와 URL 앞부분을 함께 정한다.
 *
 * <p>★ <b>이것이 생긴 이유가 실제로 뚫렸기 때문이다.</b> 예전에는 조과 인증샷과 게시글
 * 사진을 <b>한 폴더에 같은 방식으로</b> 저장하고, 접근 정책을 URL 앞부분으로만 갈랐다.
 * 파일을 읽는 쪽({@code load})은 그 정책을 몰라 파일명만 봤고, 게시글 사진 경로는 인증이
 * 없다. 그래서 <b>같은 파일을 게시판 경로로 요청하면 토큰 없이 그대로 내려왔다</b> —
 * 조과 인증샷은 약관 10조 2항이 "본인만" 이라고 약속한 기록이다.
 *
 * <p>이제 <b>폴더가 경계다.</b> 게시판 요청은 {@link #BOARD} 폴더 밖을 볼 수 없어서,
 * 소유자 확인을 건너뛸 경로 자체가 없다. 확인 코드를 한 줄 더 두는 것과 달리
 * <b>나중에 공개 서빙 경로가 하나 더 생겨도</b> 같은 구멍이 다시 열리지 않는다.
 */
public enum PhotoScope {

    /** 조과 인증샷. <b>본인만</b> 열람 — 매 요청 소유자를 확인한다. */
    CATCH("catch", "/fishing/me/photos/"),

    /** 게시글 사진. <b>누구나</b> 열람 — 글 자체가 공개고 글쓴이가 붙인 것이다. */
    BOARD("board", "/fishing/board/photos/");

    private final String directory;
    private final String urlPrefix;

    PhotoScope(String directory, String urlPrefix) {
        this.directory = directory;
        this.urlPrefix = urlPrefix;
    }

    /** 저장 루트 아래의 하위 폴더 이름. */
    public String directory() {
        return directory;
    }

    /** DB {@code photo_url} 과 서빙 경로의 앞부분. */
    public String urlPrefix() {
        return urlPrefix;
    }

    /**
     * URL 로 범위를 되찾는다. 지우는 쪽이 이걸 쓴다 — 어느 폴더에서 지울지 알아야 한다.
     *
     * <p>⚠️ 예전 {@code fileNameOf} 는 조과 경로만 벗겨낼 줄 알아서, 게시글 사진을
     * 지우라고 하면 <b>조용히 아무것도 안 했다.</b> 지운 글의 사진이 디스크에 남아
     * 공개 URL 로 계속 열렸다. 범위를 열거로 만들면 그런 한쪽만 아는 코드가 안 생긴다.
     *
     * @return 우리가 저장한 형태가 아니면 null
     */
    public static PhotoScope of(String photoUrl) {
        if (photoUrl == null) {
            return null;
        }
        for (PhotoScope scope : values()) {
            if (photoUrl.startsWith(scope.urlPrefix)) {
                return scope;
            }
        }
        return null;
    }
}
