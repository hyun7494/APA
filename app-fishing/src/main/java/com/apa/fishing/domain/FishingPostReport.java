package com.apa.fishing.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 신고 한 건.
 *
 * <p>좋아요({@link FishingPostLike})처럼 복합키로 두지 않고 자기 id 를 준다 — 신고는
 * 취소하는 값이 아니라 <b>남는 기록</b>이고, 나중에 운영 도구가 건별로 가리킬 수 있어야 한다.
 * 중복은 표의 {@code UNIQUE (post_id, user_id)} 가 막는다 (V12).
 *
 * <p><b>이 엔티티로 저장하지 않는다.</b> 넣는 일은
 * {@link com.apa.fishing.repository.FishingPostReportRepository#insertIfAbsent} 가
 * 네이티브 upsert 로 하고 (이유는 그쪽 주석), 여기는 나중에 운영 도구가 읽을 자리다.
 */
@Entity
@Table(name = "fishing_post_reports")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class FishingPostReport {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "post_id", nullable = false)
    private Long postId;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ReportReason reason;

    /** `기타` 일 때만 채워진다. */
    @Column(length = 300)
    private String detail;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;
}
