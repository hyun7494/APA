package com.apa.fishing.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

/** 날짜 × 12띠 운세. (fortune_date, zodiac) 이 유니크다. Step 7 배치가 매일 채운다. */
@Entity
@Table(name = "fishing_daily_fortune")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class DailyFortune {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "fortune_date", nullable = false)
    private LocalDate fortuneDate;

    /** RAT ~ PIG 대문자 코드. 한글로 들어가면 프론트가 전부 RAT 으로 매칭한다. */
    @Column(nullable = false)
    private String zodiac;

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
