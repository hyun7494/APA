package com.apa.fishing.repository;

import com.apa.fishing.domain.FishingPostComment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.Modifying;

import java.util.List;

public interface FishingPostCommentRepository extends JpaRepository<FishingPostComment, Long> {

    /** 댓글은 오래된 것부터 읽는다 — 대화 순서다. 글 목록(최신순)과 반대인 것이 맞다. */
    List<FishingPostComment> findByPostIdOrderByCreatedAtAsc(Long postId);

    long countByPostId(Long postId);

    /** 댓글도 같이 가린다 — 글만 가리면 댓글에 옛 이름이 그대로 남는다. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update FishingPostComment c set c.authorNickname = :masked where c.userId = :userId")
    int maskAuthor(@Param("userId") Long userId, @Param("masked") String masked);

    /** 공개 프로필의 댓글 수. 내용은 안 보여 주고 활동량만 센다. */
    long countByUserId(Long userId);
}
