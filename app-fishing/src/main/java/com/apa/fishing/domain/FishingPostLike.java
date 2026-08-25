package com.apa.fishing.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.Objects;

/**
 * 좋아요 한 번. 복합 기본키 {@code (post_id, user_id)} 가 <b>같은 사람의 중복 좋아요를 막는다</b> —
 * 토글이 연달아 눌려도 DB 가 걸러 준다.
 *
 * <p><b>이 엔티티로 저장하지 않는다.</b> 넣는 일은
 * {@link com.apa.fishing.repository.FishingPostLikeRepository#insertIfAbsent} 가 네이티브
 * upsert 로 하고 (이유는 그쪽 주석), 여기는 세거나 지울 때 쓰는 자리다.
 */
@Entity
@Table(name = "fishing_post_likes")
@IdClass(FishingPostLike.Key.class)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class FishingPostLike {

    @Id
    @Column(name = "post_id", nullable = false)
    private Long postId;

    @Id
    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    public record Key(Long postId, Long userId) implements Serializable {

        public Key() {
            this(null, null);
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Key other)) return false;
            return Objects.equals(postId, other.postId) && Objects.equals(userId, other.userId);
        }

        @Override
        public int hashCode() {
            return Objects.hash(postId, userId);
        }
    }
}
