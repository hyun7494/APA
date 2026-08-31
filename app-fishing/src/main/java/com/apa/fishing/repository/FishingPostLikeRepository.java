package com.apa.fishing.repository;

import com.apa.fishing.domain.FishingPostLike;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;

public interface FishingPostLikeRepository
        extends JpaRepository<FishingPostLike, FishingPostLike.Key> {

    /**
     * 아직 안 눌렀을 때만 넣는다. <b>넣었는지 여부가 곧 직전 상태</b>라 토글의 판정을 겸한다 —
     * "조회한 뒤 없으면 저장" 처럼 두 걸음으로 나누지 않는다.
     *
     * <p>나누면 같은 순간 두 번 눌렸을 때 둘 다 "없음" 을 보고 저장하러 가서 PK 에 걸리는데,
     * <b>JPA 는 제약 위반이 나는 순간 트랜잭션을 롤백 전용으로 표시한다</b> — 예외를 잡고
     * 정상 반환해도 커밋에서 {@code UnexpectedRollbackException} 이 나서 500 이 된다
     * ({@link FishingPostReportRepository#insertIfAbsent} 와 같은 이유).
     *
     * @return 새로 눌렀으면 1, 이미 눌러 둔 상태였으면 0
     */
    @Modifying
    @Query(value = "INSERT INTO fishing_post_likes (post_id, user_id, created_at) "
            + "VALUES (:postId, :userId, now()) "
            + "ON CONFLICT (post_id, user_id) DO NOTHING", nativeQuery = true)
    int insertIfAbsent(@Param("postId") Long postId, @Param("userId") Long userId);

    boolean existsByPostIdAndUserId(Long postId, Long userId);

    void deleteByPostIdAndUserId(Long postId, Long userId);

    /** 탈퇴 정리용. 좋아요는 집계에만 쓰이고 이름이 안 붙어 지워도 대화가 안 깨진다. */
    void deleteByUserId(Long userId);

    long countByPostId(Long postId);

    /**
     * 목록에서 "내가 누른 글" 을 <b>한 번에</b> 읽는다. 글마다 물으면 20개 목록에 20번 질의다.
     */
    @Query("select l.postId from FishingPostLike l "
            + "where l.userId = :userId and l.postId in :postIds")
    List<Long> findLikedPostIds(@Param("userId") Long userId,
                                @Param("postIds") Collection<Long> postIds);
}
