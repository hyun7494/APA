package com.apa.fishing.dto;

/**
 * 좋아요 토글 결과.
 *
 * <p>수와 상태를 <b>함께</b> 돌려준다. 프론트가 자기 쪽에서 +1 하면 다른 사람이 그 사이에
 * 누른 것이 반영되지 않아 화면과 서버가 조금씩 어긋난다.
 */
public record LikeResponse(int likeCount, boolean likedByMe) {
}
