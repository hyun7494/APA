package com.apa.fishing.batch;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 단기예보 발표 회차 선택. 아무 시각이나 넣으면 빈 응답이 온다.
 *
 * <p>발표는 하루 8번(02·05·08·11·14·17·20·23시)이고, <b>발표 직후 약 10분간은 데이터가 없다.</b>
 * 그래서 10분 버퍼를 두고 직전 회차를 고른다.
 *
 * <p>가장 놓치기 쉬운 건 <b>날짜 롤오버</b>다 — 00:00~02:10 사이에 돌면 오늘이 아니라
 * <b>어제 2300 회차</b>를 써야 한다.
 */
public final class KmaBaseTime {

    private KmaBaseTime() {
    }

    /** 발표 시각(시). 오름차순이어야 한다. */
    private static final int[] SLOTS = {2, 5, 8, 11, 14, 17, 20, 23};

    /** 발표 후 데이터가 올라올 때까지의 여유. */
    private static final int PUBLISH_BUFFER_MINUTES = 10;

    public record BaseTime(LocalDate baseDate, String baseTime) {

        /** 공공 API 는 yyyyMMdd 문자열을 받는다. */
        public String baseDateString() {
            return baseDate.format(java.time.format.DateTimeFormatter.BASIC_ISO_DATE);
        }
    }

    public static BaseTime resolve(LocalDateTime now) {
        LocalDateTime t = now.minusMinutes(PUBLISH_BUFFER_MINUTES);

        for (int i = SLOTS.length - 1; i >= 0; i--) {
            if (t.getHour() >= SLOTS[i]) {
                return new BaseTime(t.toLocalDate(), String.format("%02d00", SLOTS[i]));
            }
        }
        // 02:10 이전 → 어제 마지막 회차
        return new BaseTime(t.toLocalDate().minusDays(1), "2300");
    }
}
