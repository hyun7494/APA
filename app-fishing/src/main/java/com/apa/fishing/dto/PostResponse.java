package com.apa.fishing.dto;

import java.time.LocalDateTime;

/** 계약서 3-6. 게시판 테이블은 Step 8에서 생기므로 지금은 하드코딩 값을 담는 그릇이다. */
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
}
