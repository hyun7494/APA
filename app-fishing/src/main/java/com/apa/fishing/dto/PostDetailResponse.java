package com.apa.fishing.dto;

import com.apa.fishing.domain.FishingPost;

import java.time.LocalDateTime;

/**
 * 글 상세 (계약서 3-6-1).
 *
 * <p>목록({@link PostResponse})과 다른 점은 <b>{@code content} 가 요약이 아니라 본문 전체</b>라는
 * 것 하나다. 목록에 본문을 전부 실어 보낼 이유가 없어서 두 모양으로 나눠 둔다.
 */
public record PostDetailResponse(
        Long id,
        String category,
        String title,
        String content,
        String authorNickname,
        LocalDateTime createdAt,
        int likeCount,
        int commentCount,
        boolean hasImage,
        /** 붙인 사진. 없으면 null 이고 프론트는 자리를 만들지 않는다. */
        String photoUrl,
        String regionName,
        /**
         * 고치기 화면이 지역 칩을 되살리는 데 쓴다. 이름만으로는 못 고른다 —
         * 이름이 겹치거나 바뀌면 엉뚱한 권역이 선택된다.
         */
        Long regionGroupId,
        String boardKey,
        boolean likedByMe,
        /** 내가 쓴 글인가. 나중에 수정·삭제 버튼을 붙일 자리다. */
        boolean mine
) {

    private static final String ALL_BOARD = "ALL";

    public static PostDetailResponse from(FishingPost post, boolean likedByMe, Long viewerId) {
        String regionName = post.getRegion() == null ? null : post.getRegion().getName();

        return new PostDetailResponse(
                post.getId(),
                post.getCategory().name(),
                post.getTitle(),
                post.getContent(),
                post.getAuthorNickname(),
                post.getCreatedAt(),
                post.getLikeCount(),
                post.getCommentCount(),
                post.isHasImage(),
                post.getPhotoUrl(),
                regionName,
                post.getRegion() == null ? null : post.getRegion().getId(),
                regionName == null ? ALL_BOARD : regionName,
                likedByMe,
                viewerId != null && viewerId.equals(post.getUserId()));
    }
}
