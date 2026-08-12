package com.apa.fishing.batch.khoa;

import com.apa.fishing.batch.publicapi.PublicApiUri;
import com.apa.fishing.config.PublicApiProperties;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;

import java.net.URI;
import java.time.Duration;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

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

    private final WebClient webClient;
    private final PublicApiProperties properties;

    public KhoaClient(WebClient.Builder webClientBuilder, PublicApiProperties properties) {
        this.webClient = webClientBuilder.build();
        this.properties = properties;
    }

    /**
     * 장소 한 곳의 {@code targetDate} 요약을 가져온다.
     *
     * @param placeName KHOA 의 {@code seafsPstnNm}. 우리 포인트명과 다를 수 있다
     * @param shore     갯바위면 true, 선상이면 false ({@code gubun} 은 필수 파라미터다)
     * @throws KhoaApiException 키 미설정·호출 실패·응답 오류. 배치는 포인트별로 이걸 잡고 넘어간다
     */
    public KhoaFishingIndex fetch(String placeName, boolean shore, LocalDate targetDate) {
        if (!properties.hasKhoaKey()) {
            throw new KhoaApiException("KHOA_SERVICE_KEY 가 비어 있다");
        }

        URI uri = PublicApiUri.of(ENDPOINT)
                .param("serviceKey", properties.khoaServiceKey())
                .param("type", "json")
                .param("gubun", shore ? "갯바위" : "선상")
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
            throw new KhoaApiException(
                    "바다낚시지수 호출 실패 (placeName=" + placeName + "): " + e.getMessage(), e);
        }

        return FishingIndexParser.parse(body, targetDate);
    }
}
