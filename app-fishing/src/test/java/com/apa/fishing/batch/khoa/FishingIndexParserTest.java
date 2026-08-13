package com.apa.fishing.batch.khoa;

import com.apa.fishing.domain.Rating;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 검증 기준은 <b>2026-08-12 욕지도 실측 응답</b>이다
 * ({@code src/test/resources/khoa/fcst-fishing-yokjido.json}, 손대지 말 것).
 * 기관이 항목명이나 등급 표기를 바꾸면 여기서 깨져야 한다.
 */
class FishingIndexParserTest {

    private static final LocalDate TARGET = LocalDate.of(2026, 8, 12);

    private static String realSample() throws IOException {
        try (InputStream in = FishingIndexParserTest.class
                .getResourceAsStream("/khoa/fcst-fishing-yokjido.json")) {
            assertThat(in).as("실측 샘플 리소스").isNotNull();
            return new String(in.readAllBytes(), StandardCharsets.UTF_8);
        }
    }

    @Test
    @DisplayName("실측 응답을 포인트 한 줄로 요약한다")
    void parsesRealSample() throws IOException {
        KhoaFishingIndex index = FishingIndexParser.parse(realSample(), TARGET);

        assertThat(index.placeName()).isEqualTo("욕지도");
        assertThat(index.tideInfo()).isEqualTo("중조기");
        // 오전 26.20~26.30 / 오후 26.30~26.40 → 전체 26.20~26.40 의 중간
        assertThat(index.waterTemp()).isEqualTo(26.3);
        assertThat(index.waveHeight()).isEqualTo(0.7);
        // 오전 최대 4.9 가 오후 3.8 보다 크다
        assertThat(index.windSpeed()).isEqualTo(4.9);
    }

    @Test
    @DisplayName("어종별 지수 중 가장 좋은 값을 포인트 등급으로 삼는다")
    void takesBestSpeciesAsSpotRating() throws IOException {
        // 실측: 돌돔 좋음 / 감성돔·참돔 보통 / 벵에돔 오전 나쁨.
        // 한 어종이라도 잘 물면 갈 만한 곳이므로 최악값이 아니라 최선값을 쓴다.
        assertThat(FishingIndexParser.parse(realSample(), TARGET).rating()).isEqualTo(Rating.GOOD);
    }

    @Test
    @DisplayName("추천 어종은 최고 등급을 받은 것만, 중복 없이 담는다")
    void recommendsOnlyTopSpecies() throws IOException {
        // 돌돔은 오전·오후 두 행으로 오지만 한 번만 나와야 한다.
        assertThat(FishingIndexParser.parse(realSample(), TARGET).recommendedFish())
                .containsExactly("돌돔");
    }

    @Test
    @DisplayName("'기타어종'은 추천에서 뺀다 — 어종 바구니라 화면에 띄울 이름이 아니다")
    void excludesTheOthersBucket() {
        String body = envelope(
                item("2026-08-12", "오전", "기타어종", "좋음"),
                item("2026-08-12", "오전", "돌돔", "좋음"));

        KhoaFishingIndex index = FishingIndexParser.parse(body, TARGET);

        assertThat(index.rating()).isEqualTo(Rating.GOOD);   // 등급 계산에는 쓴다
        assertThat(index.recommendedFish()).containsExactly("돌돔");
    }

    @Test
    @DisplayName("최고 등급이 '기타어종'뿐이면 추천 목록은 빈다 (등급은 그대로)")
    void allowsEmptyRecommendation() {
        String body = envelope(
                item("2026-08-12", "오전", "기타어종", "좋음"),
                item("2026-08-12", "오전", "돌돔", "보통"));

        KhoaFishingIndex index = FishingIndexParser.parse(body, TARGET);

        assertThat(index.rating()).isEqualTo(Rating.GOOD);
        assertThat(index.recommendedFish()).isEmpty();
    }

    @Test
    @DisplayName("어종명 '-'는 추천에서 뺀다 — 어종 구분이 없는 장소가 쓰는 표기다")
    void excludesTheDashPlaceholder() {
        // 2026-08-13 전수 조회: '인천항 서측(24km)' 등 10행짜리 장소는 어종을 '-' 하나로만 준다.
        // 거르지 않으면 프론트 추천 어종 칸에 '-' 가 그대로 뜬다.
        String body = envelope(
                item("2026-08-12", "오전", "-", "좋음"),
                item("2026-08-12", "오후", "-", "보통"));

        KhoaFishingIndex index = FishingIndexParser.parse(body, TARGET);

        assertThat(index.rating()).isEqualTo(Rating.GOOD);   // 등급은 그대로 쓴다
        assertThat(index.recommendedFish()).isEmpty();
    }

    @Test
    @DisplayName("5일치가 한 응답에 오므로 대상 날짜만 골라낸다")
    void filtersByTargetDate() {
        String body = envelope(
                item("2026-08-12", "오전", "돌돔", "보통"),
                item("2026-08-13", "오전", "돌돔", "매우좋음"));

        assertThat(FishingIndexParser.parse(body, TARGET).rating()).isEqualTo(Rating.NORMAL);
        assertThat(FishingIndexParser.parse(body, LocalDate.of(2026, 8, 13)).rating())
                .isEqualTo(Rating.VERY_GOOD);
    }

    @Test
    @DisplayName("등급 표기의 공백 흔들림('매우 좋음')을 흡수한다")
    void toleratesSpacingInIndexLabels() {
        String body = envelope(item("2026-08-12", "오전", "돌돔", "매우 좋음"));

        assertThat(FishingIndexParser.parse(body, TARGET).rating()).isEqualTo(Rating.VERY_GOOD);
    }

    @Test
    @DisplayName("우리 enum 은 4단계라 '매우나쁨'은 BAD 로 접힌다")
    void foldsVeryBadIntoBad() {
        String body = envelope(item("2026-08-12", "오전", "돌돔", "매우나쁨"));

        assertThat(FishingIndexParser.parse(body, TARGET).rating()).isEqualTo(Rating.BAD);
    }

    @Test
    @DisplayName("수치 필드가 null 이면 0.0 이 아니라 null 로 남는다")
    void missingNumbersStayNull() {
        String body = """
                {"header":{"resultCode":"00","resultMsg":"NORMAL_SERVICE"},"body":{"items":{"item":[\
                {"seafsPstnNm":"욕지도","predcYmd":"2026-08-12","predcNoonSeCd":"오전",\
                "seafsTgfshNm":"돌돔","tdlvHrCn":"중조기","maxWvhgt":null,"totalIndex":"좋음"}\
                ]},"pageNo":1,"numOfRows":10,"totalCount":1,"type":"json"}}""";

        KhoaFishingIndex index = FishingIndexParser.parse(body, TARGET);

        assertThat(index.waveHeight()).isNull();
        assertThat(index.windSpeed()).isNull();
        assertThat(index.waterTemp()).isNull();
        assertThat(index.rating()).isEqualTo(Rating.GOOD);
    }

    @Test
    @DisplayName("봉투에 response 래퍼가 없다 — 기상청 모양으로 오면 실패해야 한다")
    void rejectsKmaShapedEnvelope() {
        String body = """
                {"response":{"header":{"resultCode":"00"},"body":{"items":{"item":[]}}}}""";

        assertThatThrownBy(() -> FishingIndexParser.parse(body, TARGET))
                .isInstanceOf(KhoaApiException.class);
    }

    @Test
    @DisplayName("게이트웨이 오류는 XML 로 온다 — 오퍼레이션명을 틀렸을 때 나오는 응답")
    void rejectsXmlGatewayError() {
        String xml = """
                <OpenAPI_ServiceResponse><cmmMsgHeader>\
                <errMsg>NO_OPENAPI_SERVICE_ERROR</errMsg>\
                <returnReasonCode>12</returnReasonCode></cmmMsgHeader></OpenAPI_ServiceResponse>""";

        assertThatThrownBy(() -> FishingIndexParser.parse(xml, TARGET))
                .isInstanceOf(KhoaApiException.class)
                .hasMessageContaining("게이트웨이");
    }

    @Test
    @DisplayName("대상 날짜에 쓸 값이 없으면 실패다 — 빈 요약을 성공으로 넘기면 안 된다")
    void rejectsEmptyResultForTargetDate() {
        String body = envelope(item("2026-08-14", "오전", "돌돔", "좋음"));

        assertThatThrownBy(() -> FishingIndexParser.parse(body, TARGET))
                .isInstanceOf(KhoaApiException.class);
    }

    private static String item(String date, String noon, String fish, String index) {
        return """
                {"seafsPstnNm":"욕지도","lat":34.62111,"lot":128.25611,"predcYmd":"%s",\
                "predcNoonSeCd":"%s","seafsTgfshNm":"%s","tdlvHrCn":"중조기",\
                "minWvhgt":0.7,"maxWvhgt":0.7,"minWtem":26.20,"maxWtem":26.30,\
                "minArtmp":24.7,"maxArtmp":28.5,"minCrsp":0.20,"maxCrsp":0.20,\
                "minWspd":3.3,"maxWspd":4.9,"totalIndex":"%s"}"""
                .formatted(date, noon, fish, index);
    }

    private static String envelope(String... items) {
        return """
                {"header":{"resultCode":"00","resultMsg":"NORMAL_SERVICE"},\
                "body":{"items":{"item":[%s]},"pageNo":1,"numOfRows":300,\
                "totalCount":%d,"type":"json"}}"""
                .formatted(String.join(",", items), items.length);
    }
}
