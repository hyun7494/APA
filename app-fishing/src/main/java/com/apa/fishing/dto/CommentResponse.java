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
        String content,
        LocalDateTime createdAt,
        boolean mine
) {

    public static CommentResponse from(FishingPostComment comment, Long viewerId) {
        return new CommentResponse(
                comment.getId(),
                comment.getAuthorNickname(),
                comment.getContent(),
                comment.getCreatedAt(),
                viewerId != null && comment.ownedBy(viewerId));
    }
}
