package com.apa.fishing.batch;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;

/**
 * 운세 배치의 시각 담당. 생성 로직({@link FortuneGenerator})과 클래스를 나눈 이유는
 * 같은 빈 안에서 호출하면 self-invocation 이라 {@code @Transactional} 프록시를 타지 않기
 * 때문이다 (조용히 트랜잭션 없이 돌아 원인 찾기 어렵다).
 *
 * <p>개발 노트북에서는 00:10에 서버가 떠 있는 일이 드물어 이 배치는 사실상 잘 안 돈다.
 * 실제로 하루치를 채우는 건 조회 시점의 폴백 생성 쪽이다 (FortuneService 참고).
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class FortuneScheduler {

    private final FortuneGenerator fortuneGenerator;

    @Scheduled(cron = "0 10 0 * * *", zone = "Asia/Seoul")
    public void generateToday() {
        LocalDate today = LocalDate.now(FortuneGenerator.KST);
        int created = fortuneGenerator.generateIfAbsent(today);
        if (created == 0) {
            log.info("운세 배치: {} 는 이미 있어 건너뜀", today);
        }
    }
}
