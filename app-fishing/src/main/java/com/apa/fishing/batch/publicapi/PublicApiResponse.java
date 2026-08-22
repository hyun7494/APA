package com.apa.fishing.batch.publicapi;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import java.nio.charset.StandardCharsets;
import java.util.function.BiFunction;

/**
 * 포털 응답의 <b>게이트웨이 단계</b> 판정. 기관·서비스와 무관하게 모양이 같은 부분만 여기서 본다.
 *
 * <p>봉투는 기관마다 다르다 — 기상청은 {@code {"response":{"header":…,"body":…}}} 인데
 * 국립해양조사원은 {@code response} 래퍼 없이 {@code {"header":…,"body":…}} 다.
 * 그래서 <b>봉투 안쪽 해석은 각 파서가</b> 하고, 여기서는 게이트웨이 오류만 걸러낸다.
 *
 * <p>게이트웨이 오류의 함정: {@code type=json} / {@code dataType=JSON} 을 줬어도
 * <b>XML 로 돌아온다.</b> Jackson 에 그대로 넣으면 "JSON 파싱 실패"라는 엉뚱한 메시지가 나와서
 * 진짜 원인(키·경로)을 가린다.
 */
public final class PublicApiResponse {

    private PublicApiResponse() {
    }

    private static final ObjectMapper MAPPER = new ObjectMapper();

    /** 게이트웨이 오류 봉투의 최상위 키. 정상 응답에는 없다. */
    private static final String GATEWAY_ERROR_ROOT = "OpenAPI_ServiceResponse";

    /**
     * 게이트웨이 오류가 아니면 파싱된 루트를 돌려준다.
     *
     * @param label    예외 메시지에 붙일 서비스 이름 ("단기예보" 등)
     * @param failWith 실패 시 던질 예외 생성자 (메시지, 원인)
     */
    public static JsonNode readRoot(String body, String label,
                                    BiFunction<String, Throwable, RuntimeException> failWith) {
        if (body == null || body.isBlank()) {
            throw failWith.apply(label + " 응답이 비어 있다", null);
        }
        if (body.stripLeading().startsWith("<")) {
            // 정상 응답은 JSON 이다. XML 이면 게이트웨이가 뱉은 오류다
            throw failWith.apply(label + " 게이트웨이 오류 응답: " + summarize(body), null);
        }

        JsonNode root;
        try {
            root = MAPPER.readTree(body);
        } catch (Exception e) {
            throw failWith.apply(label + " 응답을 JSON 으로 읽지 못했다: " + summarize(body), e);
        }

        if (root.has(GATEWAY_ERROR_ROOT)) {
            String errMsg = root.path(GATEWAY_ERROR_ROOT).path("cmmMsgHeader").path("errMsg").asText();
            throw failWith.apply(label + " 게이트웨이 오류 응답: " + errMsg, null);
        }
        return root;
    }

    public static String summarize(String body) {
        return body.length() <= 200 ? body : body.substring(0, 200) + "…";
    }

    /**
     * HTTP 오류의 <b>사유</b>까지 담은 메시지.
     *
     * <p>4xx·5xx 면 WebClient 는 본문을 주지 않고 예외를 던진다. 그런데 <b>진짜 원인은 그 본문에
     * 있다</b> — 포털은 403 을 내면서 본문에 {@code SERVICE_KEY_IS_NOT_REGISTERED_ERROR} 같은
     * 코드를 담는다. 상태만 남기면 로그에 "403 Forbidden" 이 전부라, 키가 틀린 것인지 활용신청이
     * 죽은 것인지 트래픽을 넘긴 것인지 구분할 수 없다 (2026-08-19~22 에 여기서 사흘 헤맸다).
     *
     * <p>본문은 한 줄로 접어서 붙인다. 포털 오류 봉투는 여러 줄 JSON·XML 이라 그대로 넣으면
     * 로그 한 건이 화면을 덮는다. <b>요청 URI 는 넣지 않는다 — 서비스키가 그 안에 있다.</b>
     */
    public static String describe(Exception e) {
        if (e instanceof WebClientResponseException failure) {
            String body = failure.getResponseBodyAsString(StandardCharsets.UTF_8);
            if (body != null && !body.isBlank()) {
                return e.getMessage() + " — 응답: " + summarize(body.replaceAll("\\s+", " ").trim());
            }
        }
        return e.getMessage();
    }
}
