package com.apa.fishing.dto;

import com.apa.fishing.domain.DailyFortune;
import com.apa.fishing.domain.Zodiac;

import java.time.LocalDate;

/** 계약서 3-5. 문자열 필드는 비어도 프론트가 ""로 처리하므로 크래시는 없다. */
public record FortuneResponse(
        LocalDate fortuneDate,
        String zodiac,
        int score,
        String totalComment,
        String love,
        String money,
        String fishing,
        String health,
        String luckyDirection,
        String luckyTime
) {

    public static FortuneResponse from(DailyFortune fortune) {
        return new FortuneResponse(
                fortune.getFortuneDate(),
                fortune.getZodiac().name(),
                fortune.getScore(),
                fortune.getTotalComment(),
                fortune.getLove(),
                fortune.getMoney(),
                fortune.getFishing(),
                fortune.getHealth(),
                fortune.getLuckyDirection(),
                fortune.getLuckyTime()
        );
    }

    /**
     * 해당 띠의 운세가 DB에 하나도 없고 생성까지 실패했을 때 쓰는 빈 응답.
     * 프론트는 {@code res.data!} 로 단정하고 읽기 때문에 404나 빈 본문을 주면 화면이 죽는다.
     */
    public static FortuneResponse empty(Zodiac zodiac, LocalDate date) {
        return new FortuneResponse(date, zodiac.name(), 0, "", "", "", "", "", "", "");
    }
}
