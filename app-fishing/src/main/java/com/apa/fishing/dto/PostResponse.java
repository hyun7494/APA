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
        String regionName,
        String boardKey,
        boolean likedByMe
) {

    /** 목록 카드에 들어가는 길이. 본문 전체를 목록에 실어 보낼 이유가 없다. */
    private static final int SUMMARY_LIMIT = 100;

    /** 지역 없는 글의 boardKey. 프론트는 regionName 이 null 이면 "전체" 로 표시한다. */
    private static final String ALL_BOARD = "ALL";

    public static PostResponse from(FishingPost post) {
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
                regionName,
                regionName == null ? ALL_BOARD : regionName,
                // Step 9(인증)에서 로그인 유저 기준으로 채운다. 그전까지는 항상 false 다.
                false
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
