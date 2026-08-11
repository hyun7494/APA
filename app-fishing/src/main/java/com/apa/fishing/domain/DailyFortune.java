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
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

/** 날짜 × 12띠 운세. (fortune_date, zodiac) 이 유니크다. Step 7 배치가 매일 채운다. */
@Entity
@Table(name = "fishing_daily_fortune")
@Getter
@Builder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor(access = AccessLevel.PRIVATE)
public class DailyFortune {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "fortune_date", nullable = false)
    private LocalDate fortuneDate;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private Zodiac zodiac;

    @Column(nullable = false)
    private int score;

    @Column(name = "total_comment")
    private String totalComment;

    private String love;
    private String money;
    private String fishing;
    private String health;

    @Column(name = "lucky_direction")
    private String luckyDirection;

    @Column(name = "lucky_time")
    private String luckyTime;
}
