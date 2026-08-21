package com.apa.auth.domain;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * APA 공통 사용자. <b>앱별이 아니라 계정 단위다</b> — 낚시 앱과 이후 앱이 같은 행을 쓰고,
 * 어느 앱에서 들어왔는지는 {@link UserAppLink} 가 기록한다.
 *
 * <p>비밀번호 컬럼이 없다. 소셜 로그인만 받으므로 우리가 자격증명을 보관하지 않는다 —
 * 유출될 것이 없는 편이 낫다.
 */
@Entity
@Table(name = "users")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class User {

    /** 이 값이 JWT subject 이자 각 앱 스키마의 {@code user_id} 다. */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(name = "social_type", nullable = false, length = 10)
    private SocialType socialType;

    /** 제공자가 준 고유 식별자. 카카오는 숫자, 구글은 sub 문자열이라 VARCHAR 로 받는다. */
    @Column(name = "social_id", nullable = false, length = 100)
    private String socialId;

    @Column(nullable = false, length = 30)
    private String nickname;

    @Column(name = "profile_url", length = 500)
    private String profileUrl;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private UserStatus status;

    @Column(name = "withdrawn_at")
    private LocalDateTime withdrawnAt;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    public static User register(SocialType socialType, String socialId, String nickname, String profileUrl) {
        User user = new User();
        user.socialType = socialType;
        user.socialId = socialId;
        user.nickname = trimNickname(nickname);
        user.profileUrl = trimProfileUrl(profileUrl);
        user.status = UserStatus.ACTIVE;
        user.createdAt = LocalDateTime.now();
        user.updatedAt = user.createdAt;
        return user;
    }

    /**
     * 로그인할 때마다 제공자 쪽 최신 값으로 맞춘다.
     *
     * <p><b>빈 값으로는 덮지 않는다.</b> 카카오는 사용자가 프로필 제공에 동의하지 않으면
     * 닉네임을 아예 안 준다. 그때 덮어쓰면 멀쩡히 쓰던 이름이 로그인 한 번에 사라진다.
     */
    public void syncProfile(String nickname, String profileUrl) {
        boolean changed = false;
        String newNickname = trimNickname(nickname);
        if (newNickname != null && !newNickname.equals(this.nickname)) {
            this.nickname = newNickname;
            changed = true;
        }
        String newProfileUrl = trimProfileUrl(profileUrl);
        if (newProfileUrl != null && !newProfileUrl.equals(this.profileUrl)) {
            this.profileUrl = newProfileUrl;
            changed = true;
        }
        if (changed) this.updatedAt = LocalDateTime.now();
    }

    public boolean isActive() {
        return status == UserStatus.ACTIVE;
    }

    /**
     * 컬럼이 30자다. 카카오 닉네임 제한은 그보다 길 수 있어 자른다 —
     * 여기서 막으면 남의 서비스 정책 때문에 우리 로그인이 실패한다.
     */
    private static String trimNickname(String value) {
        if (value == null || value.isBlank()) return null;
        String trimmed = value.trim();
        return trimmed.length() <= 30 ? trimmed : trimmed.substring(0, 30);
    }

    /** 컬럼이 500자다. URL 이 그보다 길면 없는 것으로 본다 — 잘린 URL 은 어차피 안 열린다. */
    private static String trimProfileUrl(String value) {
        if (value == null || value.isBlank()) return null;
        String trimmed = value.trim();
        return trimmed.length() <= 500 ? trimmed : null;
    }
}
