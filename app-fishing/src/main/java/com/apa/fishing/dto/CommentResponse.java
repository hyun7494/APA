package com.apa.fishing.dto;

import com.apa.fishing.domain.FishingPostComment;

import java.time.LocalDateTime;

/**
 * 댓글 하나.
 *
 * @param mine 내가 쓴 댓글인가. 프론트가 이 값으로 삭제 버튼을 보일지 정한다 —
 *             화면에서 감추는 것은 편의일 뿐이고, 실제 권한은 서버가 다시 확인한다
 */
public record CommentResponse(
        Long id,
        String authorNickname,
        /**
         * 작성자. 프로필로 넘어가는 데 쓴다 (계약서 3-10). 시드 댓글은 null 이다.
         *
         * <p>닉네임이 아니라 이걸로 넘어간다 — 이름은 표시용이고 신원은 id 다.
         */
        Long authorId,
        String content,
        LocalDateTime createdAt,
        boolean mine
) {

    public static CommentResponse from(FishingPostComment comment, Long viewerId) {
        return new CommentResponse(
                comment.getId(),
                comment.getAuthorNickname(),
                comment.getUserId(),
                comment.getContent(),
                comment.getCreatedAt(),
                viewerId != null && comment.ownedBy(viewerId));
    }
}
