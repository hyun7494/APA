package com.apa.fishing.service;

import com.apa.fishing.dto.SpotResponse;
import com.apa.fishing.batch.FortuneGenerator;
import com.apa.fishing.batch.Haversine;
import com.apa.fishing.domain.FishingSpot;
import com.apa.fishing.domain.SpotDailyIndex;
import com.apa.fishing.dto.DailyIndexResponse;
import com.apa.fishing.repository.FishingSpotRepository;
import com.apa.fishing.repository.SpotDailyIndexRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class SpotService {

    private final FishingSpotRepository spotRepository;
    private final SpotDailyIndexRepository dailyIndexRepository;

    /** regionGroupId 가 없으면 전체를 준다 (지역 필터 없는 화면·수동 확인용). */
    public List<SpotResponse> findByRegion(Long regionGroupId) {
        var spots = regionGroupId == null
                ? spotRepository.findAllWithRegion()
                : spotRepository.findByRegionId(regionGroupId);

        // ⚠️ 포인트마다 물으면 목록 하나에 질의가 포인트 수만큼 나간다. 한 번에 읽고 나눈다
        //    (도감의 @BatchSize 를 붙인 것과 같은 이유).
        Map<Long, List<DailyIndexResponse>> weeks = weeksOf(
                spots.stream().map(FishingSpot::getId).toList());

        return spots.stream()
                .map(spot -> SpotResponse.from(spot, weeks.getOrDefault(spot.getId(), List.of())))
                .toList();
    }

    /**
     * 이름으로 포인트 검색. 검색어가 비면 빈 목록이다 — 전체를 주면 검색 결과가 아니라
     * 목록이 되고, 화면이 그걸 `포인트` 섹션에 그대로 쏟는다.
     */
    public List<SpotResponse> searchByName(String query) {
        if (query == null || query.isBlank()) {
            return List.of();
        }
        var spots = spotRepository.searchByName(query.trim());
        Map<Long, List<DailyIndexResponse>> weeks = weeksOf(
                spots.stream().map(FishingSpot::getId).toList());

        return spots.stream()
                .map(spot -> SpotResponse.from(spot, weeks.getOrDefault(spot.getId(), List.of())))
                .toList();
    }

    /**
     * 홈 요약 카드에 쓸 <b>오늘 가장 좋은 포인트</b> 한 곳.
     *
     * <p>예전엔 앱이 "첫 지역의 첫 포인트" 를 골랐다. 권역이 4개에 51곳이 된 뒤로 그건
     * <b>id 가 가장 작은 곳</b>이라는 뜻밖에 없었고, 화면 카피가 "오늘 출조, 어떠세요?"
     * 인데 임의의 한 곳을 보여 주고 있었다.
     *
     * <p>고르는 일을 서버가 한다 — 앱이 <b>한 곳을 보여주려고 51곳을 받아 갈 이유가
     * 없다</b> ({@link #findNearby} 와 같은 이유). 앱은 요청도 한 번만 한다(예전엔
     * 지역 목록 → 포인트 목록으로 두 번이었다).
     *
     * <p>고르는 순서 — 등급이 좋은 순, 같으면 <b>잔잔한 순</b>(파고 → 풍속), 그래도
     * 같으면 id. 등급이 4단계뿐이라 동점이 흔한데, 마지막 기준이 없으면 같은 날
     * 새로고침할 때마다 다른 곳이 뜬다.
     *
     * <p>⚠️ 잴 수 없는 값은 <b>뒤로</b> 보낸다. null 을 0 으로 치면 파고·풍속을 못 받은
     * 곳이 "가장 잔잔한 곳" 이 되어 맨 앞에 선다.
     *
     * @return 포인트가 하나도 없으면 {@code null}
     */
    public SpotResponse findFeatured() {
        return spotRepository.findAllWithRegion().stream()
                .min(Comparator
                        .<FishingSpot>comparingInt(s -> s.getRating().ordinal())
                        .thenComparing(FishingSpot::getWaveHeight,
                                Comparator.nullsLast(Comparator.naturalOrder()))
                        .thenComparing(FishingSpot::getWindSpeed,
                                Comparator.nullsLast(Comparator.naturalOrder()))
                        .thenComparing(FishingSpot::getId))
                .map(spot -> SpotResponse.from(spot, weeksOf(List.of(spot.getId()))
                        .getOrDefault(spot.getId(), List.of())))
                .orElse(null);
    }

    /**
     * 내 위치에서 가까운 순.
     *
     * <p>거리 계산을 <b>서버가 한다</b> — 좌표는 여기 있고, 앱이 쓰지도 않을 위경도를
     * 51곳치 받아 갈 이유가 없다. 포인트가 수백 곳이 되면 PostGIS 로 옮길 것이고
     * 그때도 이 메서드 안만 바뀐다.
     *
     * <p>좌표가 없는 포인트는 뺀다 — 거리를 0 으로 두면 목록 맨 앞에 붙는다.
     */
    public List<SpotResponse> findNearby(double latitude, double longitude, int limit) {
        var spots = spotRepository.findAllWithRegion().stream()
                .filter(s -> s.getLatitude() != null && s.getLongitude() != null)
                .map(s -> Map.entry(s, Haversine.km(
                        latitude, longitude,
                        s.getLatitude().doubleValue(), s.getLongitude().doubleValue())))
                .sorted(Map.Entry.comparingByValue())
                .limit(limit)
                .toList();

        Map<Long, List<DailyIndexResponse>> weeks = weeksOf(
                spots.stream().map(e -> e.getKey().getId()).toList());

        return spots.stream()
                .map(e -> SpotResponse
                        .from(e.getKey(), weeks.getOrDefault(e.getKey().getId(), List.of()))
                        // 소수점 한 자리면 충분하다. `12.34km` 는 읽는 사람에게 의미가 없다.
                        .withDistance(Math.round(e.getValue() * 10) / 10.0))
                .toList();
    }

    public SpotResponse findOne(Long id) {
        return spotRepository.findWithRegionById(id)
                .map(spot -> SpotResponse.from(
                        spot, weeksOf(List.of(id)).getOrDefault(id, List.of())))
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "포인트를 찾을 수 없습니다: " + id));
    }

    /**
     * 오늘 이후의 예보만 준다. 지난 날짜는 화면에 쓸 일이 없고, 배치가 지우기 전이라도
     * 여기서 걸러야 어제 것이 스트립 맨 앞에 남지 않는다.
     */
    private Map<Long, List<DailyIndexResponse>> weeksOf(List<Long> spotIds) {
        if (spotIds.isEmpty()) {
            return Map.of();
        }
        LocalDate today = LocalDate.now(FortuneGenerator.KST);

        return dailyIndexRepository
                .findBySpotIdInAndForecastDateGreaterThanEqualOrderByForecastDate(spotIds, today)
                .stream()
                .collect(Collectors.groupingBy(
                        SpotDailyIndex::getSpotId,
                        Collectors.mapping(DailyIndexResponse::from, Collectors.toList())));
    }
}
