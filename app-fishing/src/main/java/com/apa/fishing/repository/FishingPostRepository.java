package com.apa.fishing.repository;

import com.apa.fishing.domain.FishingPost;
import com.apa.fishing.domain.PostCategory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface FishingPostRepository extends JpaRepository<FishingPost, Long> {

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
}
