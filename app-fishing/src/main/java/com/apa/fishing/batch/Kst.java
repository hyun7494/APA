package com.apa.fishing.batch;

import java.time.ZoneId;

/**
 * 한국 표준시. 배치·서비스가 "오늘" 을 판정할 때 반드시 이걸 쓴다.
 *
 * <p>기본 시간대에 기대면 서버가 UTC 로 뜨는 순간 자정 전후로 날짜가 하루 어긋난다 —
 * 예보 갱신과 "오늘의 지수" 가 다른 날을 가리키게 된다.
 *
 * <p>원래 {@code FortuneGenerator.KST} 였는데 운세를 걷어내면서(2026-09-01) 여기로 왔다.
 */
public final class Kst {

    public static final ZoneId ZONE = ZoneId.of("Asia/Seoul");

    private Kst() {
    }
}
