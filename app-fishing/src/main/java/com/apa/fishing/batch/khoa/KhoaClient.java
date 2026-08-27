package com.apa.fishing.batch.khoa;

import com.apa.fishing.batch.publicapi.PublicApiResponse;
import com.apa.fishing.batch.publicapi.PublicApiUri;
import com.apa.fishing.config.PublicApiProperties;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;

import java.net.URI;
import java.time.Duration;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;

/**
 * 국립해양조사원 바다낚시지수 조회. 수온·파고·풍속·유속·물때와 <b>어종별 지수</b>를 한 번에 준다.
 *
 * <p>data.go.kr ID 15142486. 오퍼레이션명이 관례를 안 따른다 —
 * {@code GetFcstFishingApiServicev2} 로 <b>대문자 G</b> 다. 소문자로 부르면
 * {@code NO_OPENAPI_SERVICE_ERROR} 가 뜬다.
 *
 * <p>이 API 가 파고·풍속까지 주므로 기상청 단기예보의 역할은 <b>날씨 표기(맑음/흐림/비)</b> 하나로
 * 줄어든다. 파고·풍속은 해상 관측 기반인 이쪽이 낫다.
 */
@Component
public class KhoaClient {

    private static final String ENDPOINT =
            "https://apis.data.go.kr/1192136/fcstFishingv2/GetFcstFishingApiServicev2";

    /**
     * 한 장소가 (5일 × 오전·오후 × 어종 5) = 50행이다. 기본값 10 으로는 하루치도 못 채운다.
     * 최대값이 300 이라 그 이상은 받을 수 없다.
     */
    private static final int NUM_OF_ROWS = 300;

    private static final Duration TIMEOUT = Duration.ofSeconds(10);

    /** {@code reqDate} 는 yyyyMMdd 인데 응답의 {@code predcYmd} 는 yyyy-MM-dd 다. 헷갈리기 쉽다. */
    private static final DateTimeFormatter REQ_DATE = DateTimeFormatter.BASIC_ISO_DATE;

    /**
     * 필수 파라미터라 보내야 하지만 <b>결과를 바꾸지 않는다.</b>
     *
     * <p>2026-08-13 에 5개 해역을 {@code 갯바위} / {@code 선상} 으로 각각 받아
     * (날짜 × 오전·오후 × 어종) 키로 맞춰 비교했더니 <b>차이 0건 / 동일 240건</b>이었다.
     * 파고·풍속·수온·{@code totalIndex} 가 전부 같다. 그래서 포인트 종류로 분기하지 않는다.
     * 기관이 나중에 실제로 갈라놓으면 이 상수부터 인자로 되돌릴 것.
     */
    private static final String GUBUN = "갯바위";

    private final WebClient webClient;
    private final PublicApiProperties properties;

    public KhoaClient(WebClient.Builder webClientBuilder, PublicApiProperties properties) {
        this.webClient = webClientBuilder.build();
        this.properties = properties;
    }

    /**
     * 장소 한 곳의 예보를 가져온다 — <b>오늘 요약과 주간을 한 번에</b>.
     *
     * <p>{@code reqDate} 를 오늘로 주면 응답에 <b>오늘 + 6일</b>이 들어온다
     * (2026-08-27 실측: 60행 / 7일). 예전에는 그중 오늘만 파싱하고 나머지를 버렸다.
     *
     * @param placeName KHOA 의 {@code seafsPstnNm}. <b>낚시 포인트명이 아니라 해역명</b>이다
     *                  (전국 49곳). 우리 포인트에는 좌표 거리로 붙였다 — V6 마이그레이션 주석 참고
     * @throws KhoaApiException 키 미설정·호출 실패·응답 오류. 배치는 포인트별로 이걸 잡고 넘어간다
     */
    public KhoaFishingResult fetch(String placeName, LocalDate targetDate) {
        if (!properties.hasKhoaKey()) {
            throw new KhoaApiException("KHOA_SERVICE_KEY 가 비어 있다");
        }

        URI uri = PublicApiUri.of(ENDPOINT)
                .param("serviceKey", properties.khoaServiceKey())
                .param("type", "json")
                .param("gubun", GUBUN)
                .param("reqDate", targetDate.format(REQ_DATE))
                .param("placeName", placeName)
                .param("numOfRows", NUM_OF_ROWS)
                .param("pageNo", 1)
                .build();

        String body;
        try {
            body = webClient.get()
                    .uri(uri)                       // URI 를 넘기면 추가 인코딩이 없다
                    .retrieve()
                    .bodyToMono(String.class)
                    .timeout(TIMEOUT)
                    .block();
        } catch (Exception e) {
            throw new KhoaApiException("바다낚시지수 호출 실패 (placeName=" + placeName + "): "
                    + PublicApiResponse.describe(e), e);
        }

        List<KhoaDailyIndex> week = FishingIndexParser.parseDaily(body);

        KhoaFishingIndex today;
        try {
            today = FishingIndexParser.parse(body, targetDate);
        } catch (KhoaApiException e) {
            // 오늘치가 없어도 주간은 쓸 수 있다. 예보 창은 발표 시각에 따라 앞으로 밀리므로
            // 여기서 통째로 던지면 있는 엿새까지 같이 버리게 된다.
            today = null;
        }
        return new KhoaFishingResult(today, week);
    }
}
