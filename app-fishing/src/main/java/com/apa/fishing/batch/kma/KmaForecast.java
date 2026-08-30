package com.apa.fishing.batch.kma;

import java.util.List;

/**
 * 단기예보에서 뽑아낸 포인트 한 곳의 하루치 요약.
 *
 * <p>값은 <b>출조 시간대(06~18시)의 최악값</b>이다. 평균이 아니다 — 안전 관련 지수라
 * "평균은 잔잔한데 오후에 3m"인 날을 좋은 날로 보이게 하면 안 된다.
 *
 * <p>{@code waveHeight}(WAV)는 <b>null 일 수 있다.</b> 내륙 격자에는 WAV 카테고리 자체가
 * 응답에 없다. 포인트 격자가 잘못 계산됐을 때 조용히 0.0 이 되지 않도록 null 로 남긴다.
 *
 * @param hourly 06/09/12/15/18/21시 조황 예상치. 상세 화면 막대그래프가 이걸 그린다.
 *               <b>여섯 칸을 다 못 채우면 통째로 null 이다</b> — 일부만 그리면 빠진 시간대가
 *               "조황 0" 으로 읽힌다. 그래프에는 빈 자리와 0 을 구별할 방법이 없다
 */
public record KmaForecast(String weather, Double windSpeed, Double waveHeight,
                          List<Integer> hourly) {
}
