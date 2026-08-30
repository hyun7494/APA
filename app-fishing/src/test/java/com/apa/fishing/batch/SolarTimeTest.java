package com.apa.fishing.batch;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 일출·일몰. 키 없이 도는 순수 함수라 {@link GridConverterTest} 와 같은 자리에 둔다.
 *
 * <p>분 단위 정확도를 주장하지 않는다 — 여기서 지키는 건 <b>천문학적으로 어긋나지
 * 않는다</b>는 것이다. 절기·경도·위도가 각각 옳은 방향으로 움직이면 충분하다.
 */
class SolarTimeTest {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul");

    /** V5·V14 가 넣어 둔 실제 좌표. */
    private static final double[] GURYONGPO = {35.990, 129.553};   // 동해, 가장 동쪽
    private static final double[] YEONGJONG = {37.4913, 126.522};  // 서해, 가장 서쪽
    private static final double[] SEOGWIPO = {33.245, 126.560};    // 제주, 가장 남쪽

    private static LocalTime sunrise(double[] point, LocalDate date) {
        return LocalTime.parse(SolarTime.describe(point[0], point[1], date, KST).split(" / ")[0]);
    }

    private static LocalTime sunset(double[] point, LocalDate date) {
        return LocalTime.parse(SolarTime.describe(point[0], point[1], date, KST).split(" / ")[1]);
    }

    @Test
    @DisplayName("한국 위도에서는 언제나 값이 나온다 — 백야·극야가 없다")
    void alwaysResolvesInKorea() {
        for (int month = 1; month <= 12; month++) {
            LocalDate date = LocalDate.of(2026, month, 15);
            assertThat(SolarTime.describe(GURYONGPO[0], GURYONGPO[1], date, KST))
                    .as("%s 구룡포", date)
                    .isNotNull()
                    .matches("\\d{2}:\\d{2} / \\d{2}:\\d{2}");
        }
    }

    @Test
    @DisplayName("★ 해는 뜨고 나서 진다")
    void risesBeforeItSets() {
        LocalDate date = LocalDate.of(2026, 8, 30);
        assertThat(sunrise(GURYONGPO, date)).isBefore(sunset(GURYONGPO, date));
    }

    @Test
    @DisplayName("★ 하지가 동지보다 낮이 길다")
    void summerDayIsLonger() {
        LocalDate summer = LocalDate.of(2026, 6, 21);
        LocalDate winter = LocalDate.of(2026, 12, 21);

        long summerMinutes = minutesBetween(sunrise(GURYONGPO, summer), sunset(GURYONGPO, summer));
        long winterMinutes = minutesBetween(sunrise(GURYONGPO, winter), sunset(GURYONGPO, winter));

        // 한국의 하지 낮은 14시간 반 남짓, 동지는 9시간 반 남짓이다
        assertThat(summerMinutes).isGreaterThan(winterMinutes + 240);
    }

    @Test
    @DisplayName("★ 동쪽에서 먼저 뜬다 — 구룡포가 영종도보다 이르다")
    void eastRisesFirst() {
        LocalDate date = LocalDate.of(2026, 8, 30);
        assertThat(sunrise(GURYONGPO, date)).isBefore(sunrise(YEONGJONG, date));
    }

    @Test
    @DisplayName("★ 겨울엔 남쪽(제주)이 북쪽(영종도)보다 낮이 길다")
    void southHasLongerWinterDay() {
        LocalDate winter = LocalDate.of(2026, 12, 21);

        assertThat(minutesBetween(sunrise(SEOGWIPO, winter), sunset(SEOGWIPO, winter)))
                .isGreaterThan(minutesBetween(sunrise(YEONGJONG, winter), sunset(YEONGJONG, winter)));
    }

    @Test
    @DisplayName("8월 말 한국의 일출·일몰이 상식적인 범위에 있다")
    void landsInPlausibleBand() {
        LocalDate date = LocalDate.of(2026, 8, 30);

        assertThat(sunrise(YEONGJONG, date))
                .isBetween(LocalTime.of(5, 30), LocalTime.of(6, 30));
        assertThat(sunset(YEONGJONG, date))
                .isBetween(LocalTime.of(18, 30), LocalTime.of(19, 30));
    }

    private static long minutesBetween(LocalTime from, LocalTime to) {
        return java.time.Duration.between(from, to).toMinutes();
    }
}
