package com.apa.fishing.domain;

import com.apa.common.time.Kst;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OrderColumn;
import jakarta.persistence.Table;
import org.hibernate.annotations.BatchSize;

import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * 조과 기록. 도감 획득 여부는 별도 플래그가 아니라 <b>이 테이블에 해당 species_id 레코드가
 * 1건이라도 있는지</b>로 판단한다 (기획서 v2 3-3).
 *
 * <p><b>서버는 어종·길이를 검증하지 않는다.</b> Rev 2 에서 자동 판별과 자동 측정을 걷어냈으므로
 * 두 값 모두 사용자 자기신고이고, 검증할 근거 자체가 없다. 금지체장 미만이어도 등록을 막지 않는다 —
 * 막으면 사용자가 길이를 거짓으로 적게 되고 데이터만 나빠진다 (기획서 5-4 ③).
 *
 * <p>{@code user_id} 는 auth 스키마 users 를 참조하지만 FK 를 걸지 않는다
 * ({@code fishing_user_favorites} 와 같은 이유 — 서비스별 스키마 독립성).
 */
@Entity
@Table(name = "fishing_user_catches")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class CatchRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    /**
     * 어종 마스터에서 <b>내린 종(is_active=false)도 그대로 남는다.</b> 이미 등록한 기록을
     * 마스터 사정으로 지우면 도감 칸이 통째로 사라진다.
     */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "species_id", nullable = false)
    private Species species;

    /**
     * 인증샷. 시안대로 <b>최대 5장</b>이고 <b>순서가 있다</b> — 첫 장이 도감 칸의 표지가 된다.
     *
     * <p>엔티티가 아니라 {@code @ElementCollection} 인 이유: 사진은 기록에 딸린 값이지 스스로
     * 존재하는 것이 아니다. 기록을 지우면 함께 사라지고, 따로 조회할 일도 없다.
     *
     * <p>{@code @BatchSize} 는 도감 때문이다. 어종 36칸이 각자 기록을 들고 있어서, 없으면
     * 사진을 읽느라 질의가 기록 수만큼 나간다.
     */
    @ElementCollection(fetch = FetchType.LAZY)
    @CollectionTable(
            name = "fishing_catch_photos",
            joinColumns = @JoinColumn(name = "catch_id"))
    @OrderColumn(name = "sort_order")
    @Column(name = "photo_url", nullable = false)
    @BatchSize(size = 50)
    private List<String> photoUrls = new ArrayList<>();

    /**
     * 사용자가 자로 재서 직접 입력한 길이. DECIMAL 이라 BigDecimal 이다 ({@link Species} 와 같은 이유).
     *
     * <p><b>선택이다</b> (V11). 놓아준 물고기나 사진만 남기고 싶은 기록이 있다 —
     * 길이를 모른다고 등록을 막을 이유가 없다. 도감의 최고 기록은 길이가 있는 것 중에서만 고른다.
     */
    @Column(name = "length_cm")
    private BigDecimal lengthCm;

    @Column(name = "weight_g")
    private Integer weightG;

    @Column(name = "caught_at", nullable = false)
    private LocalDateTime caughtAt;

    /** 선택. 등록된 포인트가 아닌 곳에서 잡을 수 있어 {@link #spotName} 자유 입력과 함께 둔다. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "region_group_id")
    private FishingRegion region;

    @Column(name = "spot_name")
    private String spotName;

    private String memo;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    private CatchRecord(Long userId, Species species, BigDecimal lengthCm, LocalDateTime caughtAt) {
        this.userId = userId;
        this.species = species;
        this.lengthCm = lengthCm;
        this.caughtAt = caughtAt;
        // DB 기본값이 now() 지만 JPA INSERT 는 컬럼을 명시해 보내므로 여기서 채운다.
        // 비워 두면 not-null 위반으로 등록 자체가 실패한다.
        this.createdAt = Kst.now();
    }

    public static CatchRecord create(Long userId, Species species,
                                     BigDecimal lengthCm, LocalDateTime caughtAt) {
        return new CatchRecord(userId, species, lengthCm, caughtAt);
    }

    /** 선택 입력들. 등록과 수정이 같은 경로를 타도록 한곳에 모았다. */
    public void describe(Integer weightG, FishingRegion region, String spotName, String memo) {
        this.weightG = weightG;
        this.region = region;
        this.spotName = spotName;
        this.memo = memo;
    }

    /**
     * 사진을 갈아 끼운다. <b>기존 목록을 통째로 바꾼다</b> — 수정 화면이 남길 장과 새로 고른 장을
     * 합쳐 최종 목록으로 보내므로, 여기서 부분 갱신을 흉내 낼 이유가 없다.
     *
     * <p>{@code orphanRemoval} 대신 {@code clear()} + {@code addAll()} 인 것은
     * {@code @ElementCollection} 이라 컬렉션 자체가 소유 관계이기 때문이다.
     */
    public void replacePhotos(List<String> urls) {
        this.photoUrls.clear();
        this.photoUrls.addAll(urls);
    }

    /** 도감 칸의 표지. 사진이 없으면 null 이다. */
    public String coverPhotoUrl() {
        return photoUrls.isEmpty() ? null : photoUrls.get(0);
    }

    /** 수정에서 쓴다. 사진은 {@link #replacePhotos} 로 따로 간다 — 안 바꾸는 경우가 많아서다. */
    public void reviseMeasurement(BigDecimal lengthCm, LocalDateTime caughtAt) {
        this.lengthCm = lengthCm;
        this.caughtAt = caughtAt;
    }

    /**
     * 어종 정정. 잘못 고른 어종을 고치면 <b>도감 칸 두 개가 같이 움직인다</b> — 옮겨 간 칸이 열리고,
     * 원래 칸에 다른 기록이 없으면 다시 잠긴다. 별도 처리는 없다. 도감이 매번 다시 세어지기 때문이다.
     */
    public void changeSpecies(Species species) {
        this.species = species;
    }

    public boolean ownedBy(Long userId) {
        return this.userId.equals(userId);
    }
}
