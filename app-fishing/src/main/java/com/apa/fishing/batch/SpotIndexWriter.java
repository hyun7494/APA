package com.apa.fishing.batch;

import com.apa.fishing.domain.FishingSpot;
import com.apa.fishing.batch.khoa.KhoaDailyIndex;
import com.apa.fishing.repository.FishingSpotRepository;
import com.apa.fishing.repository.SpotDailyIndexRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 포인트 한 곳의 갱신을 커밋한다. {@link SpotIndexBatch} 와 <b>클래스를 나눈 이유</b>가 두 가지다.
 *
 * <ol>
 *   <li>같은 빈 안에서 부르면 self-invocation 이라 {@code @Transactional} 프록시를 타지 않는다.
 *       조용히 트랜잭션 없이 돌기 때문에 원인을 찾기 어렵다
 *   <li><b>HTTP 호출을 트랜잭션 밖에 두기 위해서다.</b> 포인트 6곳 × 최대 2개 API × 타임아웃 10초면
 *       한 트랜잭션이 2분 가까이 DB 커넥션을 붙들 수 있다. 배치는 트랜잭션 없이 돌면서
 *       받아온 것만 여기로 넘겨 <b>포인트당 짧은 트랜잭션</b>으로 쓴다
 * </ol>
 *
 * <p>포인트마다 따로 커밋하므로 뒤쪽 포인트가 실패해도 앞쪽 결과는 남는다.
 */
@Component
@RequiredArgsConstructor
public class SpotIndexWriter {

    private final FishingSpotRepository spotRepository;
    private final SpotDailyIndexRepository dailyIndexRepository;

    @Transactional
    public void write(Long spotId, SpotIndexUpdate update, LocalDateTime updatedAt) {
        FishingSpot spot = spotRepository.findById(spotId)
                .orElseThrow(() -> new IllegalStateException("포인트가 사라졌다: id=" + spotId));

        spot.applyIndex(
                update.rating(),
                update.recommendedFish(),
                update.waterTemp(),
                update.waveHeight(),
                update.windSpeed(),
                update.weather(),
                update.tideInfo(),
                update.comment(),
                update.hourlyForecast(),
                update.sunriseSunset(),
                updatedAt);
    }

    /**
     * 주간 예보를 하루 한 행으로 넣는다 (V13).
     *
     * <p>예보 창이 매일 겹쳐 오므로(어제 받은 D+1 이 오늘의 D+0 이다) 덮어쓰기다.
     * 등급을 못 읽은 날은 {@code FishingIndexParser.parseDaily} 가 이미 빼고 준다.
     */
    @Transactional
    public void writeWeek(Long spotId, List<KhoaDailyIndex> week, LocalDateTime updatedAt) {
        for (KhoaDailyIndex day : week) {
            dailyIndexRepository.upsert(
                    spotId,
                    day.date(),
                    day.rating().name(),
                    day.waveHeight(),
                    day.windSpeed(),
                    day.waterTemp(),
                    updatedAt);
        }
    }

    /** 지나간 예보를 치운다. 놔두면 포인트마다 하루 한 행씩 영원히 쌓인다. */
    @Transactional
    public void purgeBefore(LocalDate from) {
        dailyIndexRepository.deleteByForecastDateLessThan(from);
    }
}
