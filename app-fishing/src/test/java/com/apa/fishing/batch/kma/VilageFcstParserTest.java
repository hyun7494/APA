package com.apa.fishing.batch.kma;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** 실제 키 없이 검증 가능한 부분. 응답 봉투 모양은 포털 명세 기준이다. */
class VilageFcstParserTest {

    private static final LocalDate TARGET = LocalDate.of(2026, 8, 12);

    private static String item(String date, String time, String category, String value) {
        return """
                {"baseDate":"20260812","baseTime":"0500","category":"%s",\
                "fcstDate":"%s","fcstTime":"%s","fcstValue":"%s","nx":60,"ny":127}"""
                .formatted(category, date, time, value);
    }

    private static String envelope(String... items) {
        return """
                {"response":{"header":{"resultCode":"00","resultMsg":"NORMAL_SERVICE"},
                "body":{"dataType":"JSON","items":{"item":[%s]},
                "pageNo":1,"numOfRows":1000,"totalCount":%d}}}"""
                .formatted(String.join(",", items), items.length);
    }

    @Test
    @DisplayName("풍속·파고는 출조 시간대의 최댓값을 쓴다 — 평균이면 오후에 거칠어지는 날을 놓친다")
    void takesWorstValueInWindow() {
        String body = envelope(
                item("20260812", "0600", "WSD", "2.1"),
                item("20260812", "1200", "WSD", "5.4"),
                item("20260812", "1800", "WSD", "3.0"),
                item("20260812", "0600", "WAV", "0.4"),
                item("20260812", "1500", "WAV", "1.2"));

        KmaForecast forecast = VilageFcstParser.parse(body, TARGET);

        assertThat(forecast.windSpeed()).isEqualTo(5.4);
        assertThat(forecast.waveHeight()).isEqualTo(1.2);
    }

    @Test
    @DisplayName("출조 시간대(06~18시) 밖의 값은 무시한다")
    void ignoresValuesOutsideWindow() {
        String body = envelope(
                item("20260812", "0300", "WSD", "12.0"),   // 새벽
                item("20260812", "1200", "WSD", "3.0"),
                item("20260812", "2100", "WSD", "11.0"));  // 야간

        assertThat(VilageFcstParser.parse(body, TARGET).windSpeed()).isEqualTo(3.0);
    }

    @Test
    @DisplayName("3일치가 한 응답에 오므로 대상 날짜만 골라낸다")
    void filtersByTargetDate() {
        String body = envelope(
                item("20260812", "1200", "WSD", "3.0"),
                item("20260813", "1200", "WSD", "9.9"),
                item("20260814", "1200", "WSD", "8.8"));

        assertThat(VilageFcstParser.parse(body, TARGET).windSpeed()).isEqualTo(3.0);
        assertThat(VilageFcstParser.parse(body, LocalDate.of(2026, 8, 13)).windSpeed()).isEqualTo(9.9);
    }

    @Test
    @DisplayName("강수(PTY)가 하늘상태(SKY)를 이긴다")
    void precipitationBeatsSky() {
        String body = envelope(
                item("20260812", "1200", "SKY", "4"),   // 흐림
                item("20260812", "1200", "PTY", "1"));  // 비

        assertThat(VilageFcstParser.parse(body, TARGET).weather()).isEqualTo("비");
    }

    @Test
    @DisplayName("PTY 가 0(강수 없음)뿐이면 하늘상태를 쓴다")
    void fallsBackToSkyWhenNoPrecipitation() {
        String body = envelope(
                item("20260812", "0900", "SKY", "1"),   // 맑음
                item("20260812", "1200", "SKY", "3"),   // 구름많음
                item("20260812", "1200", "PTY", "0"));

        // 하늘상태도 나쁜 쪽을 대표값으로 삼는다
        assertThat(VilageFcstParser.parse(body, TARGET).weather()).isEqualTo("구름많음");
    }

    @Test
    @DisplayName("한 시간대라도 비가 오면 그날은 비다")
    void anyRainMakesTheDayRainy() {
        String body = envelope(
                item("20260812", "0600", "PTY", "0"),
                item("20260812", "0900", "PTY", "0"),
                item("20260812", "1500", "PTY", "4"),   // 소나기
                item("20260812", "1800", "PTY", "1"),   // 비
                item("20260812", "1200", "SKY", "1"));

        assertThat(VilageFcstParser.parse(body, TARGET).weather()).isEqualTo("비");
    }

    @Test
    @DisplayName("내륙 격자에는 WAV 가 없다 — 0.0 이 아니라 null 이어야 한다")
    void waveHeightIsNullWhenAbsent() {
        String body = envelope(
                item("20260812", "1200", "WSD", "3.0"),
                item("20260812", "1200", "SKY", "1"));

        assertThat(VilageFcstParser.parse(body, TARGET).waveHeight()).isNull();
    }

    @Test
    @DisplayName("수치 자리에 문자열이 와도 그 값만 버리고 계속 간다")
    void skipsNonNumericValues() {
        String body = envelope(
                item("20260812", "1200", "WSD", "강수없음"),
                item("20260812", "1500", "WSD", "4.2"));

        assertThat(VilageFcstParser.parse(body, TARGET).windSpeed()).isEqualTo(4.2);
    }

    @Test
    @DisplayName("게이트웨이 오류는 dataType=JSON 을 무시하고 XML 로 온다")
    void rejectsXmlGatewayError() {
        String xml = """
                <OpenAPI_ServiceResponse><cmmMsgHeader>\
                <errMsg>SERVICE_KEY_IS_NOT_REGISTERED_ERROR</errMsg>\
                <returnReasonCode>30</returnReasonCode></cmmMsgHeader></OpenAPI_ServiceResponse>""";

        assertThatThrownBy(() -> VilageFcstParser.parse(xml, TARGET))
                .isInstanceOf(KmaApiException.class)
                .hasMessageContaining("게이트웨이");
    }

    @Test
    @DisplayName("JSON 형태의 게이트웨이 오류도 errMsg 를 그대로 올린다")
    void rejectsJsonGatewayError() {
        String body = """
                {"OpenAPI_ServiceResponse":{"cmmMsgHeader":\
                {"errMsg":"NO_OPENAPI_SERVICE_ERROR","returnReasonCode":"12"}}}""";

        assertThatThrownBy(() -> VilageFcstParser.parse(body, TARGET))
                .isInstanceOf(KmaApiException.class)
                .hasMessageContaining("NO_OPENAPI_SERVICE_ERROR");
    }

    @Test
    @DisplayName("resultCode 가 00 이 아니면 실패다 (03 = 데이터 없음)")
    void rejectsNonOkResultCode() {
        String body = """
                {"response":{"header":{"resultCode":"03","resultMsg":"NO_DATA"},"body":{}}}""";

        assertThatThrownBy(() -> VilageFcstParser.parse(body, TARGET))
                .isInstanceOf(KmaApiException.class)
                .hasMessageContaining("03");
    }

    @Test
    @DisplayName("대상 날짜에 쓸 값이 하나도 없으면 실패다 — 빈 예보를 성공으로 넘기면 안 된다")
    void rejectsEmptyResultForTargetDate() {
        String body = envelope(item("20260814", "1200", "WSD", "3.0"));

        assertThatThrownBy(() -> VilageFcstParser.parse(body, TARGET))
                .isInstanceOf(KmaApiException.class);
    }

    @Test
    @DisplayName("★ 여섯 칸(06~21시)이 다 차면 시간대별 그래프를 준다")
    void buildsHourlyGraph() {
        String[] items = new String[12];
        int[] hours = {6, 9, 12, 15, 18, 21};
        for (int i = 0; i < hours.length; i++) {
            String time = "%02d00".formatted(hours[i]);
            items[i * 2] = item("20260812", time, "WSD", "3.0");
            items[i * 2 + 1] = item("20260812", time, "WAV", "0.5");
        }

        List<Integer> hourly = VilageFcstParser.parse(envelope(items), TARGET).hourly();

        assertThat(hourly).hasSize(6).allSatisfy(v -> assertThat(v).isBetween(5, 95));
    }

    @Test
    @DisplayName("★ 한 칸이라도 비면 그래프를 통째로 포기한다 — 빈 칸은 '조황 0' 으로 읽힌다")
    void dropsGraphWhenASlotIsMissing() {
        // 21시 WSD 가 없다. 발표 시각에 따라 예보 창이 잘리면 실제로 이렇게 온다
        String body = envelope(
                item("20260812", "0600", "WSD", "3.0"),
                item("20260812", "0900", "WSD", "3.0"),
                item("20260812", "1200", "WSD", "3.0"),
                item("20260812", "1500", "WSD", "3.0"),
                item("20260812", "1800", "WSD", "3.0"));

        assertThat(VilageFcstParser.parse(body, TARGET).hourly()).isNull();
    }

    @Test
    @DisplayName("그래프는 시간대를 뭉개지 않는다 — 바람이 센 칸이 더 낮게 나온다")
    void graphKeepsEachSlotSeparate() {
        String[] items = new String[12];
        int[] hours = {6, 9, 12, 15, 18, 21};
        for (int i = 0; i < hours.length; i++) {
            String time = "%02d00".formatted(hours[i]);
            // 12시만 강풍
            items[i * 2] = item("20260812", time, "WSD", hours[i] == 12 ? "9.0" : "2.0");
            items[i * 2 + 1] = item("20260812", time, "WAV", "0.3");
        }

        List<Integer> hourly = VilageFcstParser.parse(envelope(items), TARGET).hourly();

        assertThat(hourly.get(2)).isLessThan(hourly.get(0));
        assertThat(hourly.get(2)).isEqualTo(hourly.stream().min(Integer::compare).orElseThrow());
    }
}
