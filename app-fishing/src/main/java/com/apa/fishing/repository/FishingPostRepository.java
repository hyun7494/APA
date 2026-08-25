package com.apa.fishing.repository;

import com.apa.fishing.domain.FishingPost;
import com.apa.fishing.domain.PostCategory;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface FishingPostRepository extends JpaRepository<FishingPost, Long> {

    /**
     * 글 행을 <b>잠그고</b> 읽는다. {@code like_count}·{@code comment_count} 처럼
     * "세어서 다시 넣는" 값을 고칠 때 쓴다.
     *
     * <p>⚠️ 잠그지 않으면 같은 글에 동시에 두 번 눌렸을 때 <b>캐시된 수가 실제와 어긋난 채
     * 굳는다.</b> 둘 다 상대가 커밋하기 전 값을 읽어 오는데, 나중 트랜잭션이 계산한 값이
     * 자기가 읽어 온 값과 같으면 하이버네이트는 <b>UPDATE 를 아예 내지 않는다</b> —
     * 그래서 먼저 커밋한 쪽의 틀린 값이 그대로 남는다. 실제로 `좋아요 0인데 표시는 1`
     * 상태를 재현했다 (2026-08-25).
     *
     * <p>세는 값을 고치는 경로가 늘면 여기를 함께 쓸 것. 한 글에 대한 토글이 줄을 서는 대신
     * 수가 언제나 실제 행 수와 같다.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from FishingPost p where p.id = :id")
    Optional<FishingPost> findByIdForUpdate(@Param("id") Long id);

    /**
     * 두 필터 모두 선택이다 — 전체 탭에서는 tag 가 아예 안 오고, regionGroupId 는 현재 프론트가
     * 보내지 않는다. null 이면 해당 조건을 건너뛴다.
     *
     * <p>region 은 {@code left join fetch} 다. inner join 이면 지역 없는 글(region_group_id NULL)이
     * 목록에서 통째로 사라진다.
     */
    @Query("""
            select p from FishingPost p
            left join fetch p.region r
            where (:category is null or p.category = :category)
              and (:regionGroupId is null or r.id = :regionGroupId)
            order by p.createdAt desc
            """)
    List<FishingPost> findFiltered(@Param("category") PostCategory category,
                                   @Param("regionGroupId") Long regionGroupId);
    /**
     * 마이페이지의 작성 글 수 (계약서 3-7).
     *
     * <p>{@code user_id} 가 nullable 이다 — 시드 글에는 작성자가 없다.
     * null 인 행은 어느 사용자의 것도 아니므로 이 셈에 들어오지 않는다.
     */
    long countByUserId(Long userId);
}