package com.apa.fishing.dto;

import com.apa.fishing.domain.FishingPost;

import java.time.LocalDateTime;

/** 계약서 3-6. */
public record PostResponse(
        Long id,
        String category,
        String title,
        String summary,
        String authorNickname,
        /**
         * 작성자. 프로필로 넘어가는 데 쓴다 (계약서 3-10). 시드 글은 null 이다.
         *
         * <p>닉네임이 아니라 이걸로 넘어간다 — 이름은 표시용이고 신원은 id 다.
         */
        Long authorId,
        LocalDateTime createdAt,
        int likeCount,
        int commentCount,
        boolean hasImage,
        /** 붙인 사진. 없으면 null 이고 프론트는 자리를 만들지 않는다. */
        String photoUrl,
        String regionName,
        /** 상세({@link PostDetailResponse})와 같은 값이다. 두 응답이 어긋나면 앱이 목록에서
         *  본 글과 상세에서 본 글의 지역을 다르게 안다. */
        Long regionGroupId,
        String boardKey,
        boolean likedByMe
) {

    /** 목록 카드에 들어가는 길이. 본문 전체를 목록에 실어 보낼 이유가 없다. */
    private static final int SUMMARY_LIMIT = 100;

    /** 지역 없는 글의 boardKey. regionName 이 null 이면 프론트는 지역 라벨을 안 붙인다. */
    private static final String ALL_BOARD = "ALL";

    public static PostResponse from(FishingPost post) {
        return from(post, false);
    }

    /**
     * @param likedByMe 보는 사람이 이 글을 좋아요 했는지. 비로그인이면 언제나 false 다.
     *                  목록에서는 글마다 묻지 않고 한 번에 읽어 온 집합으로 채운다
     *                  ({@code FishingPostLikeRepository.findLikedPostIds}) — 글마다 물으면
     *                  20개 목록에 질의가 20번이다
     */
    public static PostResponse from(FishingPost post, boolean likedByMe) {
        String regionName = post.getRegion() == null ? null : post.getRegion().getName();

        return new PostResponse(
                post.getId(),
                post.getCategory().name(),
                post.getTitle(),
                summarize(post.getContent()),
                post.getAuthorNickname(),
                post.getUserId(),
                post.getCreatedAt(),
                post.getLikeCount(),
                post.getCommentCount(),
                post.isHasImage(),
                post.getPhotoUrl(),
                regionName,
                post.getRegion() == null ? null : post.getRegion().getId(),
                regionName == null ? ALL_BOARD : regionName,
                likedByMe
        );
    }

    private static String summarize(String content) {
        if (content == null) {
            return "";
        }
        String flat = content.replaceAll("\\s+", " ").trim();
        return flat.length() <= SUMMARY_LIMIT ? flat : flat.substring(0, SUMMARY_LIMIT) + "…";
    }
}
