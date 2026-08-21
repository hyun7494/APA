package com.apa.auth.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.Objects;

/**
 * "이 계정이 어느 앱을 쓰는가". 계정은 APA 전체가 공유하지만 앱별 최초·최근 로그인은
 * 따로 알아야 한다 — 낚시 앱 지표에 다른 앱만 쓰는 사용자가 섞이면 안 된다.
 */
@Entity
@Table(name = "user_app_links")
@IdClass(UserAppLink.Key.class)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserAppLink {

    @Id
    @Column(name = "user_id")
    private Long userId;

    /** {@code FISHING} 같은 앱 식별자. 프론트가 로그인 요청에 함께 보낸다. */
    @Id
    @Column(name = "app_id", length = 20)
    private String appId;

    @Column(name = "first_login_at", nullable = false)
    private LocalDateTime firstLoginAt;

    @Column(name = "last_login_at", nullable = false)
    private LocalDateTime lastLoginAt;

    public static UserAppLink first(Long userId, String appId) {
        UserAppLink link = new UserAppLink();
        link.userId = userId;
        link.appId = appId;
        link.firstLoginAt = LocalDateTime.now();
        link.lastLoginAt = link.firstLoginAt;
        return link;
    }

    public void touch() {
        this.lastLoginAt = LocalDateTime.now();
    }

    /** 복합 키. */
    @NoArgsConstructor
    public static class Key implements Serializable {
        private Long userId;
        private String appId;

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Key key)) return false;
            return Objects.equals(userId, key.userId) && Objects.equals(appId, key.appId);
        }

        @Override
        public int hashCode() {
            return Objects.hash(userId, appId);
        }
    }
}
