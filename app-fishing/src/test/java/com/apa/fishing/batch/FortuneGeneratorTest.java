package com.apa.fishing.batch;

import com.apa.fishing.domain.DailyFortune;
import com.apa.fishing.domain.Zodiac;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.HashSet;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;

/** 조합 규칙만 본다 — DB도 스프링 컨텍스트도 띄우지 않는다. */
class FortuneGeneratorTest {

    private static final LocalDate DATE = LocalDate.of(2026, 8, 12);

    @Test
    @DisplayName("같은 날짜·띠는 몇 번을 만들어도 같은 결과다 (배치 재실행·폴백 생성이 겹쳐도 안전)")
    void deterministic() {
        DailyFortune first = FortuneGenerator.compose(DATE, Zodiac.DRAGON);
        DailyFortune second = FortuneGenerator.compose(DATE, Zodiac.DRAGON);

        assertThat(second.getScore()).isEqualTo(first.getScore());
        assertThat(second.getTotalComment()).isEqualTo(first.getTotalComment());
        assertThat(second.getLove()).isEqualTo(first.getLove());
        assertThat(second.getMoney()).isEqualTo(first.getMoney());
        assertThat(second.getFishing()).isEqualTo(first.getFishing());
        assertThat(second.getHealth()).isEqualTo(first.getHealth());
        assertThat(second.getLuckyDirection()).isEqualTo(first.getLuckyDirection());
        assertThat(second.getLuckyTime()).isEqualTo(first.getLuckyTime());
    }

    @Test
    @DisplayName("같은 날 12띠가 서로 다른 운세를 받는다")
    void zodiacsDifferOnTheSameDay() {
        Set<String> totals = new HashSet<>();
        for (Zodiac zodiac : Zodiac.values()) {
            DailyFortune fortune = FortuneGenerator.compose(DATE, zodiac);
            assertThat(fortune.getZodiac()).isEqualTo(zodiac);
            totals.add(fortune.getTotalComment() + fortune.getScore());
        }
        // 풀에서 뽑는 이상 완전한 유일성은 보장 못 하지만, 한두 개로 뭉치면 조합이 잘못된 것이다.
        assertThat(totals).hasSizeGreaterThan(8);
    }

    @Test
    @DisplayName("날짜가 바뀌면 문구도 바뀐다 — 매일 같은 운세가 나오면 배치의 의미가 없다")
    void variesByDate() {
        Set<String> totals = IntStream.range(0, 30)
                .mapToObj(offset -> FortuneGenerator.compose(DATE.plusDays(offset), Zodiac.RAT))
                .map(DailyFortune::getTotalComment)
                .collect(Collectors.toSet());

        assertThat(totals).hasSizeGreaterThan(3);
    }

    @Test
    @DisplayName("점수는 게이지 바에 그대로 쓰이므로 60~95 안이다")
    void scoreInRange() {
        for (Zodiac zodiac : Zodiac.values()) {
            IntStream.range(0, 60).forEach(offset -> {
                int score = FortuneGenerator.compose(DATE.plusDays(offset), zodiac).getScore();
                assertThat(score).isBetween(60, 95);
            });
        }
    }

    @Test
    @DisplayName("문구 길이가 컬럼 제한을 넘지 않는다 (VARCHAR(200) / lucky_direction VARCHAR(10))")
    void withinColumnLimits() {
        for (Zodiac zodiac : Zodiac.values()) {
            DailyFortune fortune = FortuneGenerator.compose(DATE, zodiac);

            assertThat(fortune.getTotalComment()).hasSizeLessThanOrEqualTo(200);
            assertThat(fortune.getLove()).hasSizeLessThanOrEqualTo(200);
            assertThat(fortune.getMoney()).hasSizeLessThanOrEqualTo(200);
            assertThat(fortune.getFishing()).hasSizeLessThanOrEqualTo(200);
            assertThat(fortune.getHealth()).hasSizeLessThanOrEqualTo(200);
            assertThat(fortune.getLuckyDirection()).hasSizeLessThanOrEqualTo(10);
            assertThat(fortune.getLuckyTime()).hasSizeLessThanOrEqualTo(20);
        }
    }
}
