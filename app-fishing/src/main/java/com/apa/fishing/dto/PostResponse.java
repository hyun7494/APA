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
        LocalDateTime createdAt,
        int likeCount,
        int commentCount,
        boolean hasImage,
        /** 붙인 사진. 없으면 null 이고 프론트는 자리를 만들지 않는다. */
        String photoUrl,
        String regionName,
        String boardKey,
        boolean likedByMe
) {

    /** 목록 카드에 들어가는 길이. 본문 전체를 목록에 실어 보낼 이유가 없다. */
    private static final int SUMMARY_LIMIT = 100;

    /** 지역 없는 글의 boardKey. 프론트는 regionName 이 null 이면 "전체" 로 표시한다. */
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
                post.getCreatedAt(),
                post.getLikeCount(),
                post.getCommentCount(),
                post.isHasImage(),
                post.getPhotoUrl(),
                regionName,
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
