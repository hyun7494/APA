package com.apa.fishing.repository;

import com.apa.fishing.domain.FishingUserFavorite;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface FishingUserFavoriteRepository
        extends JpaRepository<FishingUserFavorite, FishingUserFavorite.Key> {

    /** 개수는 이 목록의 크기로 센다 — 같은 수를 두 번 질의할 이유가 없다. */
    List<FishingUserFavorite> findByUserId(Long userId);

    /**
     * 없을 때만 넣는다. <b>한 문장이라 경쟁이 없다.</b>
     *
     * <p>★ 예전에는 "있나 보고 없으면 저장" 이었는데, 동시에 열두 번 부르면 절반 넘게
     * <b>500</b> 이었다. 더 고약한 것은 그다음이다 — INSERT 가 기본키에 걸리는 순간
     * <b>Postgres 가 그 트랜잭션을 통째로 무효로 만들어서</b>, 예외를 잡아 넘겨도
     * 뒤따르는 SELECT 가 {@code current transaction is aborted} 로 죽는다.
     * 자바에서 잡는 것으로는 해결되지 않고, <b>충돌 자체가 안 나게</b> 해야 한다.
     *
     * <p>⚠️ {@code ON CONFLICT} 는 Postgres 문법이다. 이 저장소는 Postgres 전용이라
     * (Flyway·스키마·타입 전부) 문제가 없지만, DB 를 바꾸면 여기를 먼저 볼 것.
     *
     * <p>{@code created_at} 은 컬럼 기본값({@code now()})이 채운다.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query(value = "INSERT INTO fishing_user_favorites (user_id, region_group_id) "
            + "VALUES (:userId, :regionGroupId) ON CONFLICT DO NOTHING", nativeQuery = true)
    int insertIfAbsent(@Param("userId") Long userId, @Param("regionGroupId") Long regionGroupId);
}
