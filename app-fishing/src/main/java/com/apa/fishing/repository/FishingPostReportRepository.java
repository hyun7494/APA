package com.apa.fishing.repository;

import com.apa.fishing.domain.FishingPostReport;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface FishingPostReportRepository extends JpaRepository<FishingPostReport, Long> {

    /**
     * 아직 신고하지 않았을 때만 넣는다.
     *
     * <p>네이티브 {@code ON CONFLICT DO NOTHING} 을 쓰는 이유가 있다. "먼저 조회하고 없으면
     * 저장" 은 같은 순간 두 번 눌리면 UNIQUE 제약에 걸리는데, <b>JPA 는 그 예외가 나는 순간
     * 트랜잭션을 롤백 전용으로 표시한다</b> — 코드에서 예외를 잡고 정상 반환해도 커밋 때
     * {@code UnexpectedRollbackException} 이 나서 500 이 된다. 여기서는 예외 자체가 나지 않는다.
     *
     * @return 새로 넣었으면 1, 이미 신고해 둔 글이면 0
     */
    @Modifying
    @Query(value = """
            INSERT INTO fishing_post_reports (post_id, user_id, reason, detail, created_at)
            VALUES (:postId, :userId, :reason, :detail, now())
            ON CONFLICT (post_id, user_id) DO NOTHING
            """, nativeQuery = true)
    int insertIfAbsent(@Param("postId") Long postId,
                       @Param("userId") Long userId,
                       @Param("reason") String reason,
                       @Param("detail") String detail);
}
