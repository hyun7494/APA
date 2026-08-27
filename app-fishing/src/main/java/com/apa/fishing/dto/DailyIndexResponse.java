package com.apa.fishing.dto;

import com.apa.fishing.domain.SpotDailyIndex;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * 주간 스트립의 한 칸 (계약서 3-3).
 *
 * <p>오늘 카드가 쓰는 값(물때·어종·날씨)은 여기 없다. 스트립은 <b>흐름만</b> 보여주는
 * 자리라 하루당 등급 하나와 안전 수치 둘이면 충분하고, 그 이상은 상세에서 본다.
 *
 * @param date       yyyy-MM-dd. 앱이 요일과 `오늘`/`내일` 표기를 직접 만든다 —
 *                   서버가 문구를 만들면 기기 시각과 어긋날 수 있다
 * @param rating     2-1 코드 (VERY_GOOD | GOOD | NORMAL | BAD)
 * @param waveHeight 그날 최대 파고. 값이 없으면 null 이고 <b>0 이 아니다</b>
 * @param windSpeed  그날 최대 풍속
 */
public record DailyIndexResponse(
        LocalDate date,
        String rating,
        Double waveHeight,
        Double windSpeed
) {

    public static DailyIndexResponse from(SpotDailyIndex day) {
        return new DailyIndexResponse(
                day.getForecastDate(),
                day.getRating().name(),
                toDouble(day.getWaveHeight()),
                toDouble(day.getWindSpeed()));
    }

    /** null 을 0 으로 바꾸지 않는다 — 안전 수치라 결측이 "잔잔한 날"로 위장되면 안 된다. */
    private static Double toDouble(BigDecimal value) {
        return value == null ? null : value.doubleValue();
    }
}
