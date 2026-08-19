package com.apa.fishing.repository;

import com.apa.fishing.domain.CatchRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

/**
 * 조과 기록 조회.
 *
 * <p>도감 집계는 SQL 로 접지 않고 <b>사용자 기록을 통째로 읽어 메모리에서 묶는다</b>
 * ({@code CollectionService}). "가장 긴 개체의 사진"처럼 집계 함수로 바로 안 나오는 값이 섞여 있어
 * SQL 로 짜면 윈도우 함수나 상관 서브쿼리가 필요한데, 기획서 3-3 의 판단대로 사용자당 레코드가
 * 수천 건을 넘길 일이 없다. 여기서 SQL 을 복잡하게 만드는 건 조기 최적화다.
 *
 * <p>{@code region} 은 nullable 이라 전부 {@code left join fetch} 다. inner join 이면 장소를 안 적은
 * 기록이 목록에서 통째로 사라진다 ({@code FishingPostRepository} 에서 겪은 것과 같은 함정).
 */
public interface CatchRecordRepository extends JpaRepository<CatchRecord, Long> {

    /** 도감 집계용 — 한 사용자의 전 기록. 정렬은 집계하는 쪽에서 한다. */
    @Query("""
            select c from CatchRecord c
            join fetch c.species
            left join fetch c.region
            where c.userId = :userId
            """)
    List<CatchRecord> findAllByUser(@Param("userId") Long userId);

    /**
     * 내 조과 목록. 프론트가 최신순을 기대한다 (mock 구현이 caughtAt 내림차순).
     *
     * <p>어종 필터를 {@code (:speciesId is null or ...)} 한 방으로 합치지 않고 메서드를 둘로 나눴다 —
     * 널 파라미터를 비교식에 넣으면 방언에 따라 타입 추론이 흔들려 런타임에야 드러난다.
     */
    @Query("""
            select c from CatchRecord c
            join fetch c.species
            left join fetch c.region
            where c.userId = :userId
            order by c.caughtAt desc, c.id desc
            """)
    List<CatchRecord> findByUserLatest(@Param("userId") Long userId);

    @Query("""
            select c from CatchRecord c
            join fetch c.species
            left join fetch c.region
            where c.userId = :userId and c.species.id = :speciesId
            order by c.caughtAt desc, c.id desc
            """)
    List<CatchRecord> findByUserAndSpeciesLatest(@Param("userId") Long userId,
                                                 @Param("speciesId") Long speciesId);

    /** 수정·삭제 대상. 소유자 확인은 서비스가 한다 — 여기서 userId 로 걸러 버리면 404 와 403 을 못 가른다. */
    @Query("""
            select c from CatchRecord c
            join fetch c.species
            left join fetch c.region
            where c.id = :id
            """)
    Optional<CatchRecord> findWithSpeciesById(@Param("id") Long id);

    /**
     * 등록 <b>직전</b>에 부른다. 등록 후에 물어보면 방금 넣은 레코드 때문에 항상 false 가 된다.
     * 이 값이 곧 프론트의 도감 획득 연출 재생 여부다 (기획서 4-2).
     */
    boolean existsByUserIdAndSpeciesId(Long userId, Long speciesId);

    /** 진행률의 분자. 같은 종을 여러 번 잡아도 칸은 하나다. */
    @Query("select count(distinct c.species.id) from CatchRecord c where c.userId = :userId")
    long countOwnedSpecies(@Param("userId") Long userId);

    /**
     * 사진 서빙의 소유자 확인. 인증샷은 기본적으로 본인만 열람이라(기획서 7장)
     * 파일명을 안다고 남의 사진이 나가면 안 된다.
     */
    boolean existsByUserIdAndPhotoUrl(Long userId, String photoUrl);
}
