package com.apa.fishing.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/** 게시글 댓글 (V9). */
@Entity
@Table(name = "fishing_post_comments")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class FishingPostComment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * 글은 연관관계로 물지 않는다. 댓글을 읽는 이유는 언제나 "이 글의 댓글" 하나뿐이라
     * 엔티티를 붙들고 있으면 얻는 것 없이 로딩만 늘어난다.
     */
    @Column(name = "post_id", nullable = false)
    private Long postId;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    /** 작성 시점 닉네임. 글과 같은 이유다 — 조회 때 auth-service 를 되부르지 않는다. */
    @Column(name = "author_nickname", nullable = false, length = 30)
    private String authorNickname;

    @Column(nullable = false, length = 500)
    private String content;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    public static FishingPostComment write(Long postId, Long userId, String authorNickname, String content) {
        FishingPostComment comment = new FishingPostComment();
        comment.postId = postId;
        comment.userId = userId;
        comment.authorNickname = authorNickname;
        comment.content = content;
        comment.createdAt = LocalDateTime.now();
        return comment;
    }

    public boolean ownedBy(Long userId) {
        return this.userId.equals(userId);
    }
}
