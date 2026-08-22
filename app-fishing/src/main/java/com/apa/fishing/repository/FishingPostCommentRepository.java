package com.apa.fishing.repository;

import com.apa.fishing.domain.FishingPostComment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface FishingPostCommentRepository extends JpaRepository<FishingPostComment, Long> {

    /** 댓글은 오래된 것부터 읽는다 — 대화 순서다. 글 목록(최신순)과 반대인 것이 맞다. */
    List<FishingPostComment> findByPostIdOrderByCreatedAtAsc(Long postId);

    long countByPostId(Long postId);
}
