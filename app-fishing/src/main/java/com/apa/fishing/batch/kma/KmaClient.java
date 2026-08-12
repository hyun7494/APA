package com.apa.fishing.batch.kma;

import com.apa.fishing.batch.KmaBaseTime;
import com.apa.fishing.config.PublicApiProperties;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;

import java.net.URI;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 기상청 단기예보 ((구) 동네예보) 조회. 날씨·풍속·파고를 여기서 받는다.
 *
 * <p>data.go.kr ID <b>15084084</b>, API 유형 REST. 이름이 거의 같은
 * <b>"기상청_단기예보 조회서비스(기상청API허브 연계)"는 다른 것</b>이다 — 그건 유형이 LINK 라
 * 데이터를 주지 않고 {@code apihub.kma.go.kr} 로 넘길 뿐이고, 허브 계정·키를 따로 발급받아야 한다.
 * 포털 키로는 호출되지 않는다.
 *
 * <p>수온은 여기 없다(기획서 4-3의 오기). 수온·물때는 국립해양조사원 쪽에서 받아야 한다.
 */
@Component
public class KmaClient {

    private static final String ENDPOINT =
            "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst";

    /**
     * 한 번 부르면 3일치가 통으로 온다 — 카테고리 × 시각으로 800줄 남짓이다.
     * 기본값 10 으로 두면 첫 몇 줄만 와서 <b>조용히 빈 결과</b>가 된다.
     */
    private static final int NUM_OF_ROWS = 1000;

    private static final Duration TIMEOUT = Duration.ofSeconds(10);

    private final WebClient webClient;
    private final PublicApiProperties properties;

    public KmaClient(WebClient.Builder webClientBuilder, PublicApiProperties properties) {
        this.webClient = webClientBuilder.build();
        this.properties = properties;
    }

    /**
     * 격자 좌표 한 곳의 {@code targetDate} 출조 시간대 요약을 가져온다.
     *
     * @throws KmaApiException 키 미설정·호출 실패·응답 오류. 배치는 포인트별로 이걸 잡고 넘어간다
     */
    public KmaForecast fetch(int nx, int ny, LocalDate targetDate, LocalDateTime now) {
        if (!properties.hasKmaKey()) {
            throw new KmaApiException("KMA_SERVICE_KEY 가 비어 있다");
        }

        KmaBaseTime.BaseTime baseTime = KmaBaseTime.resolve(now);
        URI uri = PublicApiUri.of(ENDPOINT)
                .param("serviceKey", properties.kmaServiceKey())
                .param("dataType", "JSON")
                .param("numOfRows", NUM_OF_ROWS)
                .param("pageNo", 1)
                .param("base_date", baseTime.baseDateString())
                .param("base_time", baseTime.baseTime())
                .param("nx", nx)
                .param("ny", ny)
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
            throw new KmaApiException(
                    "단기예보 호출 실패 (nx=" + nx + ", ny=" + ny + "): " + e.getMessage(), e);
        }

        return VilageFcstParser.parse(body, targetDate);
    }
}
