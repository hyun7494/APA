package com.apa.fishing.batch.khoa;

import java.util.List;

/**
 * 한 번의 호출에서 뽑아낸 두 가지.
 *
 * <p>응답 하나에 오늘 + 6일이 들어 있어서 <b>같은 본문을 두 번 파싱</b>한다. 주간을 따로
 * 받으러 가면 호출이 두 배가 되는데, 공공 API 는 일일 트래픽 한도가 있다.
 *
 * @param today 오늘 카드에 쓰는 요약. <b>null 일 수 있다</b> — 응답에 오늘 날짜가 없을 때다.
 *              그래도 [week] 는 살아 있으므로 통째로 버리지 않는다
 * @param week  응답에 담긴 모든 날짜. 날짜 오름차순
 */
public record KhoaFishingResult(KhoaFishingIndex today, List<KhoaDailyIndex> week) {
}
