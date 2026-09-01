package com.apa.fishing.dto;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 공개 프로필 (계약서 3-10) — 게시판에서 작성자를 눌렀을 때 보이는 화면.
 *
 * <p>★ <b>이미 공개된 것만 모은다.</b> 조과 기록·도감·인증샷은 여기 없다 —
 * 약관 10조 2항이 "게시판에 따로 공개하지 않는 한 다른 회원에게 노출되지 않는다" 고
 * 알린다. 남의 개인 기록을 프로필이라는 이름으로 흘리면 그 약속을 어기는 것이다.
 *
 * <p>닉네임은 <b>그 사람 글에 박힌 값</b>을 쓴다. app-fishing 은 auth 를 부르지 않고,
 * 닉네임은 유일하고 회수되지 않으므로 스냅샷이 곧 현재 이름이다.
 *
 * @param nickname     최근 글의 작성자명. 탈퇴했으면 `탈퇴한 사용자 a3f9` 가 그대로 온다
 * @param firstActivityAt 글이든 댓글이든 처음 남긴 시각. "언제부터 활동했나" 가 신뢰의 단서다
 * @param recentPosts  최신순. 전부 주지 않고 잘라서 준다 — 프로필은 목록 화면이 아니다
 */
public record PublicProfileResponse(
        Long userId,
        String nickname,
        long postCount,
        long commentCount,
        long likesReceived,
        LocalDateTime firstActivityAt,
        List<PostResponse> recentPosts
) {
}
