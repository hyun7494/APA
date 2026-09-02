package com.apa.common.time;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;

/**
 * 이 서비스들의 "지금" 과 "오늘". <b>맨 {@code LocalDateTime.now()} 를 쓰지 말 것.</b>
 *
 * <p>★ 그건 <b>JVM 기본 시간대</b>를 따른다. 개발 노트북(윈도우)에서는 KST 라 맞지만
 * <b>컨테이너는 기본이 UTC</b> 다 — 그대로 올리면 글·댓글·조과의 작성 시각과 토큰 만료가
 * 전부 아홉 시간 밀린다. 게시판이 "9시간 전" 으로 뜨는 식이다.
 *
 * <p>더 나쁜 건 <b>섞인다</b>는 것이다. 배치는 예보 날짜를 KST 로 계산하는데 글은 UTC 로
 * 저장되면, 같은 DB 안에서 두 시간대가 공존하고 `forecast_date` 와 실제 시각이 어긋난다.
 * 컬럼이 전부 {@code timestamp without time zone} 이라 나중에 어느 쪽인지 알 방법도 없다.
 *
 * <p>컨테이너에도 {@code TZ=Asia/Seoul} 을 준다. 다만 그건 <b>덤</b>이다 — 환경변수를
 * 빠뜨린 채 어디서 띄워도 여기만 통하면 값은 맞는다.
 *
 * <p>서비스 대상이 한국뿐이라 시간대를 고정한다. 나라가 늘면 그때는 컬럼을
 * {@code timestamptz} 로 옮기는 것이 먼저다 — 이 클래스로는 못 버틴다.
 */
public final class Kst {

    public static final ZoneId ZONE = ZoneId.of("Asia/Seoul");

    private Kst() {
    }

    /** 지금. `LocalDateTime.now()` 를 대신한다. */
    public static LocalDateTime now() {
        return LocalDateTime.now(ZONE);
    }

    /** 오늘. `LocalDate.now()` 를 대신한다. */
    public static LocalDate today() {
        return LocalDate.now(ZONE);
    }
}
