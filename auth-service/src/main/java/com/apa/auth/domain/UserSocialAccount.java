package com.apa.auth.domain;

import com.apa.common.time.Kst;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 한 계정에 붙은 소셜 신원. 계정 1 : 연결 N 이다 — 같은 사람이 카카오와 구글을 함께 쓸 수 있다.
 *
 * <p>DB 가 두 가지를 보장한다. {@code UNIQUE(social_type, social_id)} 는 한 소셜 계정이 두
 * 사람에게 붙는 것을, {@code UNIQUE(user_id, social_type)} 은 한 사람이 같은 제공자를 두 번
 * 붙이는 것을 막는다. 애플리케이션 검사만으로는 동시 요청에서 뚫린다.
 */
@Entity
@Table(name = "user_social_accounts")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserSocialAccount {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * FK 지만 연관관계로 매핑하지 않는다. 이 표를 읽는 이유는 언제나 "이 소셜 신원의 주인이
     * 누구냐" 하나뿐이라, 엔티티를 물고 있으면 얻는 것 없이 로딩만 늘어난다.
     */
    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(name = "social_type", nullable = false, length = 10)
    private SocialType socialType;

    /** 제공자가 준 고유 식별자. 카카오는 숫자, 구글은 sub 문자열이라 VARCHAR 로 받는다. */
    @Column(name = "social_id", nullable = false, length = 100)
    private String socialId;

    /** 연동 당시 제공자가 준 주소. 계정의 {@code users.email} 과 다를 수 있다. */
    @Column(length = 255)
    private String email;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    public static UserSocialAccount link(Long userId, SocialType socialType, String socialId, String email) {
        UserSocialAccount account = new UserSocialAccount();
        account.userId = userId;
        account.socialType = socialType;
        account.socialId = socialId;
        account.email = email;
        account.createdAt = Kst.now();
        return account;
    }
}
