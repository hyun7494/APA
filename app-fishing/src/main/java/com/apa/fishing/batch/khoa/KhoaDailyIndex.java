package com.apa.fishing.batch.khoa;

import com.apa.fishing.domain.Rating;

import java.time.LocalDate;

/**
 * 하루치 요약. 주간 스트립이 쓰는 값이다.
 *
 * <p>{@link KhoaFishingIndex}(오늘 한 곳의 전체 요약)와 나눠 둔 이유는 담는 범위가 달라서다 —
 * 이쪽은 <b>날짜마다 하나</b>고, 어종 목록·물때처럼 오늘 카드에만 쓰는 것은 들고 있지 않다.
 *
 * @param rating     그날 어종별 지수 중 <b>가장 좋은</b> 값 ({@code KhoaFishingIndex.rating} 과 같은 규칙)
 * @param waveHeight 하루 <b>최대</b> 파고. 평균이 아니다 — 안전 관련이라 최악값을 쓴다
 * @param windSpeed  하루 최대 풍속. 같은 이유
 * @param waterTemp  하루 수온 범위의 중간값
 */
public record KhoaDailyIndex(
        LocalDate date,
        Rating rating,
        Double waveHeight,
        Double windSpeed,
        Double waterTemp) {
}
