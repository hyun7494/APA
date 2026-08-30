package com.apa.fishing.batch;

import com.apa.fishing.batch.khoa.KhoaClient;
import com.apa.fishing.batch.khoa.KhoaFishingResult;
import com.apa.fishing.batch.kma.KmaClient;
import com.apa.fishing.batch.kma.KmaForecast;
import com.apa.fishing.batch.publicapi.PublicApiException;
import com.apa.fishing.config.PublicApiProperties;
import com.apa.fishing.domain.FishingSpot;
import com.apa.fishing.repository.FishingSpotRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.concurrent.CompletableFuture;

/**
 * 포인트별 공공 API 지수 갱신. 하루 한 번 전 포인트를 돈다.
 *
 * <p><b>이 클래스에는 {@code @Transactional} 이 없다.</b> HTTP 호출을 트랜잭션 밖에 두려는
 * 의도적인 선택이다 — 쓰기는 {@link SpotIndexWriter} 가 포인트마다 짧게 처리한다.
 *
 * <p><b>포인트 하나의 실패가 배치를 멈추면 안 된다.</b> 6곳 중 1곳의 해역만 응답이 없어도
 * 나머지 5곳이 어제 값에 머무는 건 말이 안 된다. 그래서 포인트마다, 그리고 기관마다
 * 따로 잡는다. 한 기관이 죽어도 다른 기관 값으로는 갱신된다.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class SpotIndexBatch {

    private final FishingSpotRepository spotRepository;
    private final SpotIndexWriter spotIndexWriter;
    private final KhoaClient khoaClient;
    private final KmaClient kmaClient;
    private final PublicApiProperties properties;

    /**
     * 기상청 02:00 발표가 확실히 올라온 뒤로 잡았다. KHOA 도 당일치를 준다.
     * (KmaBaseTime 이 알아서 직전 발표를 고르므로 시각이 조금 밀려도 무해하다)
     */
    @Scheduled(cron = "0 20 5 * * *", zone = "Asia/Seoul")
    public void refreshDaily() {
        refresh(LocalDate.now(FortuneGenerator.KST));
    }

    /**
     * 부팅 직후에도 한 번 돈다.
     *
     * <p>운세 배치에서 겪은 것과 같은 사정이다 — 개발 노트북에서 05:20 에 서버가 떠 있는 일이
     * 거의 없어서 {@code @Scheduled} 만으로는 <b>영영 안 도는 배치</b>가 된다. 그러면 포인트
     * 화면이 시드 값에 머문 채로 "잘 되는 것처럼" 보인다.
     *
     * <p>부팅을 막지 않도록 별도 스레드에서 돌린다. 키가 하나도 없으면 아예 시작하지 않는다.
     */
    @EventListener(ApplicationReadyEvent.class)
    public void refreshOnStartup() {
        if (!properties.hasKhoaKey() && !properties.hasKmaKey()) {
            log.info("지수 배치: 인증키가 없어 건너뜀 (KHOA_SERVICE_KEY / KMA_SERVICE_KEY)");
            return;
        }
        CompletableFuture.runAsync(() -> refresh(LocalDate.now(FortuneGenerator.KST)));
    }

    /**
     * @return 갱신에 성공한 포인트 수
     */
    public int refresh(LocalDate targetDate) {
        List<FishingSpot> spots = spotRepository.findAll();
        LocalDateTime updatedAt = LocalDateTime.now(FortuneGenerator.KST);
        int updated = 0;

        for (FishingSpot spot : spots) {
            if (refreshOne(spot, targetDate, updatedAt)) {
                updated++;
            }
        }

        // 지나간 예보는 화면에 쓸 일이 없다.
        spotIndexWriter.purgeBefore(targetDate);

        log.info("지수 배치: {} 기준 {}/{} 포인트 갱신", targetDate, updated, spots.size());
        return updated;
    }

    private boolean refreshOne(FishingSpot spot, LocalDate targetDate, LocalDateTime updatedAt) {
        try {
            KhoaFishingResult khoa = fetchKhoa(spot, targetDate);

            // ★ 주간은 오늘 요약과 **같은 응답**에서 나온다 (호출을 더 하지 않는다).
            //    오늘치가 비어 있어도 주간은 쓸 수 있으므로 먼저 저장한다.
            if (khoa != null) {
                spotIndexWriter.writeWeek(spot.getId(), khoa.week(), updatedAt);
            }

            SpotIndexUpdate update = SpotIndexUpdate.combine(
                    khoa == null ? null : khoa.today(),
                    fetchKma(spot, targetDate));

            if (update == null) {
                log.warn("지수 배치: [{}] 쓸 값을 하나도 못 받아 건너뜀", spot.getName());
                return false;
            }

            spotIndexWriter.write(
                    spot.getId(), update.withSunriseSunset(sunriseSunsetOf(spot, targetDate)),
                    updatedAt);
            return true;
        } catch (Exception e) {
            // 여기까지 온 건 DB 쓰기 실패 같은 예상 밖의 것이다. 그래도 다음 포인트는 돌아야 한다.
            log.error("지수 배치: [{}] 갱신 실패", spot.getName(), e);
            return false;
        }
    }

    /**
     * 일출·일몰. 좌표만 있으면 나오므로 API 실패와 무관하게 51곳 전부 채워진다.
     *
     * <p>좌표가 없는 포인트는 null 이다 — 시드 값을 남긴다. 지금은 그런 포인트가 없다.
     */
    private String sunriseSunsetOf(FishingSpot spot, LocalDate targetDate) {
        if (spot.getLatitude() == null || spot.getLongitude() == null) {
            return null;
        }
        return SolarTime.describe(
                spot.getLatitude().doubleValue(),
                spot.getLongitude().doubleValue(),
                targetDate,
                FortuneGenerator.KST);
    }

    /** {@code khoa_place_name} 이 NULL 인 포인트(영종도)는 애초에 호출하지 않는다. */
    private KhoaFishingResult fetchKhoa(FishingSpot spot, LocalDate targetDate) {
        if (spot.getKhoaPlaceName() == null) {
            return null;
        }
        try {
            return khoaClient.fetch(spot.getKhoaPlaceName(), targetDate);
        } catch (PublicApiException e) {
            log.warn("지수 배치: [{}] 바다낚시지수 실패 — {}", spot.getName(), e.getMessage());
            return null;
        }
    }

    private KmaForecast fetchKma(FishingSpot spot, LocalDate targetDate) {
        if (spot.getGridNx() == null || spot.getGridNy() == null) {
            return null;
        }
        try {
            return kmaClient.fetch(spot.getGridNx(), spot.getGridNy(), targetDate,
                    LocalDateTime.now(FortuneGenerator.KST));
        } catch (PublicApiException e) {
            log.warn("지수 배치: [{}] 단기예보 실패 — {}", spot.getName(), e.getMessage());
            return null;
        }
    }
}
