package com.apa.fishing.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.util.Objects;

/**
 * 즐겨찾는 지역. 표는 {@code V1} 부터 있었고 여기서 처음 읽는다 (마이페이지 · 계약서 3-7).
 *
 * <p>{@code user_id} 는 auth 스키마 users 를 참조하지만 FK 를 걸지 않는다 —
 * {@link CatchRecord} 와 같은 이유로 서비스별 스키마를 독립적으로 둔다.
 */
@Entity
@Table(name = "fishing_user_favorites")
@IdClass(FishingUserFavorite.Key.class)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class FishingUserFavorite {

    @Id
    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Id
    @Column(name = "region_group_id", nullable = false)
    private Long regionGroupId;

    /** 복합 기본키 (user_id, region_group_id). */
    public record Key(Long userId, Long regionGroupId) implements Serializable {

        // JPA 가 리플렉션으로 만들 수 있어야 한다.
        public Key() {
            this(null, null);
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Key other)) return false;
            return Objects.equals(userId, other.userId)
                    && Objects.equals(regionGroupId, other.regionGroupId);
        }

        @Override
        public int hashCode() {
            return Objects.hash(userId, regionGroupId);
        }
    }
}
