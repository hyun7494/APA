package com.apa.fishing.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/** 게시글. 좋아요·신고·댓글은 아직 프론트 UI 가 없다 (계약서 3-8 P2). */
@Entity
@Table(name = "fishing_posts")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class FishingPost {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private PostCategory category;

    @Column(nullable = false)
    private String title;

    @Column(nullable = false, columnDefinition = "text")
    private String content;

    /** Step 9(인증) 전까지는 비어 있다. */
    @Column(name = "user_id")
    private Long userId;

    @Column(name = "author_nickname", nullable = false)
    private String authorNickname;

    /** null 이면 지역 없는 글이다 — 프론트가 "전체" 로 표시한다. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "region_group_id")
    private FishingRegion region;

    @Column(name = "like_count", nullable = false)
    private int likeCount;

    @Column(name = "comment_count", nullable = false)
    private int commentCount;

    @Column(name = "has_image", nullable = false)
    private boolean hasImage;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    /**
     * 댓글·좋아요 수를 실제 개수로 맞춘다.
     *
     * <p><b>세어서 넣지, 직접 +1/-1 하지 않는다.</b> 증감식은 어딘가에서 한 번 어긋나면
     * 그 뒤로 영영 틀린 채로 간다 — V9 이전의 시드 값이 그 상태였다.
     */
    public void syncCommentCount(int actual) {
        this.commentCount = actual;
    }

    public void syncLikeCount(int actual) {
        this.likeCount = actual;
    }

    /**
     * 새 글.
     *
     * @param authorNickname <b>토큰에서 온 값을 그대로 박아 둔다.</b> 나중에 사용자가 닉네임을
     *                       바꿔도 이미 쓴 글의 작성자명은 그때 이름으로 남는다 — 조회할 때마다
     *                       auth-service 에 물으면 목록 한 번에 N 번 왕복하게 된다
     * @param region         지역 게시판. null 이면 전체 게시판 글이고, 프론트는 "전체" 로 그린다
     */
    public static FishingPost write(PostCategory category,
                                    String title,
                                    String content,
                                    Long userId,
                                    String authorNickname,
                                    FishingRegion region) {
        FishingPost post = new FishingPost();
        post.category = category;
        post.title = title;
        post.content = content;
        post.userId = userId;
        post.authorNickname = authorNickname;
        post.region = region;
        // 좋아요·댓글 수는 0 에서 시작한다. 컬럼이 NOT NULL 이라 비워 둘 수 없다.
        post.likeCount = 0;
        post.commentCount = 0;
        // 사진 첨부는 아직 없다 (계약서 3-8). 붙이면 이 값이 실제 첨부 여부가 된다.
        post.hasImage = false;
        post.createdAt = LocalDateTime.now();
        return post;
    }
}
