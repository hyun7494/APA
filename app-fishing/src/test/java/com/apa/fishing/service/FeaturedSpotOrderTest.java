package com.apa.fishing.service;

import com.apa.fishing.domain.Rating;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.Comparator;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 홈 대표 포인트를 고르는 순서. 스프링 없이 도는 부분만 본다 —
 * {@link SpotService#findFeatured()} 가 쓰는 것과 <b>같은 비교 규칙</b>이다.
 *
 * <p>여기서 지키는 건 셋이다: 등급이 먼저, 같으면 잔잔한 쪽, <b>못 잰 값은 뒤로</b>.
 */
class FeaturedSpotOrderTest {

    /** 엔티티는 생성자가 막혀 있어 같은 규칙을 이 레코드에 대고 확인한다. */
    private record Candidate(long id, Rating rating, BigDecimal wave, BigDecimal wind) {
    }

    private static final Comparator<Candidate> ORDER = Comparator
            .<Candidate>comparingInt(c -> c.rating().ordinal())
            .thenComparing(Candidate::wave, Comparator.nullsLast(Comparator.naturalOrder()))
            .thenComparing(Candidate::wind, Comparator.nullsLast(Comparator.naturalOrder()))
            .thenComparing(Candidate::id);

    private static Candidate best(List<Candidate> candidates) {
        return candidates.stream().min(ORDER).orElseThrow();
    }

    private static BigDecimal n(String value) {
        return value == null ? null : new BigDecimal(value);
    }

    @Test
    @DisplayName("★ 등급이 먼저다 — 잔잔해도 나쁨이면 안 뽑힌다")
    void ratingWinsFirst() {
        Candidate calm = new Candidate(1, Rating.BAD, n("0.1"), n("1.0"));
        Candidate good = new Candidate(2, Rating.VERY_GOOD, n("1.2"), n("7.0"));

        assertThat(best(List.of(calm, good))).isEqualTo(good);
    }

    @Test
    @DisplayName("★ 등급이 같으면 잔잔한 쪽 — 파고를 먼저 본다")
    void calmerWinsOnTie() {
        Candidate rough = new Candidate(1, Rating.GOOD, n("1.0"), n("2.0"));
        Candidate calm = new Candidate(2, Rating.GOOD, n("0.3"), n("6.0"));

        assertThat(best(List.of(rough, calm))).isEqualTo(calm);
    }

    @Test
    @DisplayName("★ 못 잰 값은 뒤로 — null 을 0 으로 치면 '가장 잔잔한 곳'이 되어 버린다")
    void missingReadingsSortLast() {
        Candidate unknown = new Candidate(1, Rating.GOOD, null, null);
        Candidate measured = new Candidate(2, Rating.GOOD, n("0.9"), n("5.0"));

        assertThat(best(List.of(unknown, measured))).isEqualTo(measured);
    }

    @Test
    @DisplayName("★ 끝까지 같으면 id — 없으면 새로고침할 때마다 다른 곳이 뜬다")
    void idBreaksTheLastTie() {
        Candidate later = new Candidate(9, Rating.GOOD, n("0.5"), n("3.0"));
        Candidate earlier = new Candidate(4, Rating.GOOD, n("0.5"), n("3.0"));

        assertThat(best(List.of(later, earlier))).isEqualTo(earlier);
        // 순서를 바꿔 넣어도 같은 답이어야 한다
        assertThat(best(List.of(earlier, later))).isEqualTo(earlier);
    }
}
