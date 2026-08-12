package com.apa.fishing.batch.kma;

/**
 * 단기예보에서 뽑아낸 포인트 한 곳의 하루치 요약.
 *
 * <p>값은 <b>출조 시간대(06~18시)의 최악값</b>이다. 평균이 아니다 — 안전 관련 지수라
 * "평균은 잔잔한데 오후에 3m"인 날을 좋은 날로 보이게 하면 안 된다.
 *
 * <p>{@code waveHeight}(WAV)는 <b>null 일 수 있다.</b> 내륙 격자에는 WAV 카테고리 자체가
 * 응답에 없다. 포인트 격자가 잘못 계산됐을 때 조용히 0.0 이 되지 않도록 null 로 남긴다.
 */
public record KmaForecast(String weather, Double windSpeed, Double waveHeight) {
}
