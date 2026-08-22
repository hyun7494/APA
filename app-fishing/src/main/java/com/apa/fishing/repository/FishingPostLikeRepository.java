package com.apa.fishing.repository;

import com.apa.fishing.domain.FishingPostLike;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;

public interface FishingPostLikeRepository
        extends JpaRepository<FishingPostLike, FishingPostLike.Key> {

    boolean existsByPostIdAndUserId(Long postId, Long userId);

    void deleteByPostIdAndUserId(Long postId, Long userId);

    long countByPostId(Long postId);

    /**
     * 목록에서 "내가 누른 글" 을 <b>한 번에</b> 읽는다. 글마다 물으면 20개 목록에 20번 질의다.
     */
    @Query("select l.postId from FishingPostLike l "
            + "where l.userId = :userId and l.postId in :postIds")
    List<Long> findLikedPostIds(@Param("userId") Long userId,
                                @Param("postIds") Collection<Long> postIds);
}
