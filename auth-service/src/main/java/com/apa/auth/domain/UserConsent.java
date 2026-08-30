package com.apa.auth.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 동의 한 건. <b>덧붙이기만 한다</b> — 고치는 메서드를 두지 않는 이유다.
 *
 * <p>철회도 새 행이다({@code agreed = false}). 한 행을 고쳐 버리면 "언제 동의했다가
 * 언제 철회했는지" 가 사라지는데, 그게 이 표의 존재 이유다. 현재 상태는
 * {@code (user_id, consent_type)} 별 가장 최근 행이다.
 */
@Entity
@Table(name = "user_consents")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserConsent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    /**
     * {@link ConsentType} 이름을 문자열로 넣는다.
     *
     * <p>{@code @Enumerated} 를 안 쓴다 — 나중에 이 표를 읽을 때 <b>지금은 없는 항목</b>이
     * 나올 수 있고(항목이 사라져도 과거 기록은 남는다), enum 매핑이면 그때 읽다가 터진다.
     */
    @Column(name = "consent_type", nullable = false, length = 40)
    private String consentType;

    /** 동의한 문서의 판. 약관이 바뀌면 판이 올라가고 재동의를 받는다. */
    @Column(nullable = false, length = 20)
    private String version;

    private boolean agreed;

    @Column(name = "agreed_at", nullable = false)
    private LocalDateTime agreedAt;

    public static UserConsent record(Long userId, ConsentType type, String version,
                                     boolean agreed, LocalDateTime at) {
        UserConsent consent = new UserConsent();
        consent.userId = userId;
        consent.consentType = type.name();
        consent.version = version;
        consent.agreed = agreed;
        consent.agreedAt = at;
        return consent;
    }
}
