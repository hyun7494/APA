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
 * <p>로그인 수단은 두 가지고 <b>한 계정이 둘 다 가질 수 있다</b>:
 * <ul>
 *   <li>이메일 + 비밀번호 — 이 행의 {@code email}/{@code passwordHash}</li>
 *   <li>소셜 — {@link UserSocialAccount} 행들 (제공자마다 하나씩)</li>
 * </ul>
 * 둘을 잇는 것이 "계정 연동"이다. 소셜 신원을 이 표에 두면 한 사람이 카카오와 구글을
 * 함께 쓸 수 없어서 밖으로 뺐다.
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

    /**
     * 로그인 아이디이자 계정을 잇는 열쇠. <b>항상 소문자로 저장한다</b> —
     * {@code A@b.com} 과 {@code a@b.com} 이 다른 계정이 되면 사용자는 자기 계정을 잃는다.
     *
     * <p>소셜로만 들어온 계정은 제공자가 주소를 주지 않았으면 null 이다.
     */
    @Column(length = 255)
    private String email;

    /** BCrypt 해시. 소셜로만 가입한 계정은 null 이다 — 비밀번호가 없는 것이 정상이다. */
    @Column(name = "password_hash", length = 100)
    private String passwordHash;

    /**
     * 이 주소의 소유가 확인됐는가.
     *
     * <p>지금 true 가 되는 경로는 <b>제공자가 확인해 준 주소로 들어온 경우</b>뿐이다.
     * 자체 가입은 확인 메일을 보낼 수단이 아직 없어 false 로 남는다. 이 값이 계정 연동의
     * 안전장치라, 자체 가입 계정에 소셜을 붙일 때는 비밀번호를 한 번 더 받는다.
     */
    @Column(name = "email_verified", nullable = false)
    private boolean emailVerified;

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

    /** 자체 회원가입. {@code email} 은 정규화(소문자)된 값이어야 한다. */
    public static User registerWithEmail(String email, String passwordHash, String nickname) {
        User user = newActive(nickname, null);
        user.email = email;
        user.passwordHash = passwordHash;
        user.emailVerified = false;
        return user;
    }

    /**
     * 소셜 가입.
     *
     * @param email 제공자가 <b>확인해 준</b> 주소만 넘긴다. 확인되지 않은 주소를 여기 넣으면
     *              다음에 그 주소의 진짜 주인이 자체 가입을 하려 할 때 막힌다
     */
    public static User registerFromSocial(String nickname, String profileUrl, String email) {
        User user = newActive(nickname, profileUrl);
        user.email = email;
        user.emailVerified = email != null;
        return user;
    }

    private static User newActive(String nickname, String profileUrl) {
        User user = new User();
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

    public boolean hasPassword() {
        return passwordHash != null;
    }

    /**
     * 탈퇴 — 행은 남기고 로그인 수단만 지운다.
     *
     * <p>★ <b>닉네임은 그대로 둔다.</b> {@code uq_users_nickname_lower} 가 계속 붙잡고 있어야
     * 떠난 사람의 이름을 아무도 못 가져간다 ({@link UserStatus} 참고). 그게 풀리면 게시글에
     * 박힌 옛 닉네임이 다른 사람 것처럼 보인다.
     *
     * <p>반대로 <b>이메일과 비밀번호는 비운다.</b>
     * <ul>
     *   <li>개인정보 처리방침이 "회원 정보는 탈퇴 시까지" 라고 알린다 — 남겨 둘 근거가 없다</li>
     *   <li>비워야 로그인할 수 없다. 상태만 바꾸면 비밀번호가 남아 인증 경로가 열려 있다</li>
     *   <li>주소가 풀리므로 <b>같은 이메일로 다시 가입할 수 있다</b>. 그때는 새 계정이고,
     *       옛 글은 가려진 채로 남는다</li>
     * </ul>
     *
     * <p>⚠️ {@code ck_users_password_needs_email} 이 "비밀번호가 있으면 이메일도 있어야 한다"
     * 이므로 <b>둘을 함께</b> 비워야 한다. 하나만 비우면 제약에 걸린다.
     */
    public void withdraw(LocalDateTime at) {
        this.status = UserStatus.WITHDRAWN;
        this.withdrawnAt = at;
        this.email = null;
        this.passwordHash = null;
        this.emailVerified = false;
        this.profileUrl = null;
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
