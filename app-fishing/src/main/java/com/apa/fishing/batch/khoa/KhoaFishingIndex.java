package com.apa.fishing.batch.khoa;

import com.apa.fishing.domain.Rating;

import java.util.List;

/**
 * 바다낚시지수에서 뽑아낸 포인트 한 곳의 하루치 요약.
 *
 * <p>원본은 <b>(오전/오후) × 어종</b>으로 쪼개져 온다. 포인트 카드는 한 줄만 보여주므로 여기서 합친다.
 * 합치는 기준이 항목마다 다르다 — 아래 각 필드 주석 참고.
 *
 * @param placeName       {@code seafsPstnNm}. 우리 포인트명과 다를 수 있어 매핑이 필요하다
 * @param rating          어종별 지수 중 <b>가장 좋은</b> 값. 한 어종이라도 잘 물면 갈 만한 곳이다
 * @param recommendedFish {@code rating} 등급에 해당하는 어종들. '기타어종'은 뺀다
 * @param waterTemp       하루 수온 범위의 중간값
 * @param waveHeight      하루 최대 파고. 평균이 아니다 — 안전 관련이라 최악값을 쓴다
 * @param windSpeed       하루 최대 풍속. 같은 이유
 * @param tideInfo        {@code tdlvHrCn} 물때 (예: 중조기)
 */
public record KhoaFishingIndex(
        String placeName,
        Rating rating,
        List<String> recommendedFish,
        Double waterTemp,
        Double waveHeight,
        Double windSpeed,
        String tideInfo) {
}
