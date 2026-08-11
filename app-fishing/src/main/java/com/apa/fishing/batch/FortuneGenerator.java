package com.apa.fishing.batch;

import com.apa.fishing.domain.DailyFortune;
import com.apa.fishing.domain.Zodiac;
import com.apa.fishing.repository.DailyFortuneRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Arrays;
import java.util.List;
import java.util.Random;

/**
 * 하루치 12띠 운세를 만든다. 외부 API를 쓰지 않고 문구 풀에서 뽑아 조합한다.
 *
 * <p>뽑기는 (날짜, 띠) 로 시드를 고정한 <b>결정론적</b> 난수다. 같은 날짜로 몇 번을 돌려도
 * 같은 결과가 나오므로, 배치가 중복 실행되거나 폴백 생성과 겹쳐도 내용이 흔들리지 않는다.
 * {@link Random} 은 알고리즘이 스펙에 박혀 있어 JVM·재시작과 무관하게 같은 수열을 준다
 * (시드에 enum 의 {@code hashCode()} 를 쓰면 안 된다 — 그건 실행마다 달라진다).
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class FortuneGenerator {

    public static final ZoneId KST = ZoneId.of("Asia/Seoul");

    private static final int MIN_SCORE = 60;
    private static final int SCORE_RANGE = 36;   // 60~95

    private final DailyFortuneRepository fortuneRepository;

    /**
     * 해당 날짜의 운세가 없으면 12띠를 한 번에 만든다.
     *
     * @return 만든 건수. 이미 있으면 0
     */
    @Transactional
    public int generateIfAbsent(LocalDate date) {
        if (fortuneRepository.existsByFortuneDate(date)) {
            return 0;
        }

        List<DailyFortune> batch = Arrays.stream(Zodiac.values())
                .map(zodiac -> compose(date, zodiac))
                .toList();
        fortuneRepository.saveAll(batch);

        log.info("운세 {}건 생성 ({})", batch.size(), date);
        return batch.size();
    }

    /** 테스트에서 직접 부를 수 있게 package-private 이다 (DB 없이 조합 규칙만 검증한다). */
    static DailyFortune compose(LocalDate date, Zodiac zodiac) {
        Random rng = new Random(seed(date, zodiac));
        return DailyFortune.builder()
                .fortuneDate(date)
                .zodiac(zodiac)
                .score(MIN_SCORE + rng.nextInt(SCORE_RANGE))
                .totalComment(FortunePhrases.pick(FortunePhrases.TOTAL, rng))
                .love(FortunePhrases.pick(FortunePhrases.LOVE, rng))
                .money(FortunePhrases.pick(FortunePhrases.MONEY, rng))
                .fishing(FortunePhrases.pick(FortunePhrases.FISHING, rng))
                .health(FortunePhrases.pick(FortunePhrases.HEALTH, rng))
                .luckyDirection(FortunePhrases.pick(FortunePhrases.DIRECTIONS, rng))
                .luckyTime(FortunePhrases.pick(FortunePhrases.TIMES, rng))
                .build();
    }

    private static long seed(LocalDate date, Zodiac zodiac) {
        return date.toEpochDay() * 31L + zodiac.name().hashCode();
    }
}
