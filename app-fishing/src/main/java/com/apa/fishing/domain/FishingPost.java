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

/** 게시글. 지금은 목록 조회만 쓴다 — 글쓰기·좋아요는 프론트 UI가 아직 없다 (계약서 3-8 P2). */
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
}
