package com.apa.fishing.batch.kma;

import com.apa.fishing.batch.publicapi.PublicApiResponse;
import com.fasterxml.jackson.databind.JsonNode;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

/**
 * {@code getVilageFcst} 응답 → {@link KmaForecast}. 순수 함수라 키 없이 단위 테스트로 검증한다.
 *
 * <p>응답은 <b>3일치가 한 덩어리로</b> 온다. 카테고리 × 시각으로 800줄 남짓이라
 * {@code numOfRows} 를 넉넉히(1000) 주지 않으면 뒷날짜가 잘려서 조용히 빈 결과가 된다.
 *
 * <p>실패 응답이 두 종류라는 게 함정이다:
 * <ul>
 *   <li>게이트웨이 단계 실패 → 최상위가 {@code OpenAPI_ServiceResponse} 이고,
 *       {@code dataType=JSON} 을 줬어도 <b>XML 로 온다</b> (키 오류·경로 오류가 여기 걸린다)</li>
 *   <li>서비스 단계 실패 → 정상 봉투에 {@code resultCode} 만 00 이 아니다 (03 = 데이터 없음)</li>
 * </ul>
 */
public final class VilageFcstParser {

    private VilageFcstParser() {
    }

    private static final String LABEL = "단기예보";

    /** 출조 시간대. 이 바깥의 새벽·야간 값은 카드 지수에 반영하지 않는다. */
    private static final int WINDOW_START_HOUR = 6;
    private static final int WINDOW_END_HOUR = 18;

    private static final String CATEGORY_WIND_SPEED = "WSD";
    private static final String CATEGORY_WAVE_HEIGHT = "WAV";
    private static final String CATEGORY_SKY = "SKY";
    private static final String CATEGORY_PRECIPITATION_TYPE = "PTY";

    private static final String RESULT_CODE_OK = "00";

    /** SKY 코드 → 표기. 2는 결번이다. */
    private static final Map<String, String> SKY_LABELS = Map.of(
            "1", "맑음",
            "3", "구름많음",
            "4", "흐림");

    /** PTY 코드 → 표기. 0은 강수 없음이라 SKY 로 넘긴다. */
    private static final Map<String, String> PRECIPITATION_LABELS = Map.of(
            "1", "비",
            "2", "비/눈",
            "3", "눈",
            "4", "소나기");

    /**
     * 나쁜 쪽이 뒤에 온다. 하루 요약은 <b>가장 나쁜 시간대</b>를 대표값으로 삼는다.
     *
     * <p>⚠️ 시드 데이터는 '구름조금'을 쓰지만 기상청에 그 등급은 없다(맑음/구름많음/흐림 3단계).
     * 배치가 돌면 '구름조금'은 사라진다. 프론트는 문자열을 그대로 렌더해서 문제 없다.
     */
    private static final List<String> WEATHER_SEVERITY =
            List.of("맑음", "구름많음", "흐림", "소나기", "비", "비/눈", "눈");

    public static KmaForecast parse(String body, LocalDate targetDate) {
        JsonNode items = readItems(body);
        String targetDateKey = targetDate.format(DateTimeFormatter.BASIC_ISO_DATE);

        Double windSpeed = null;
        Double waveHeight = null;
        String sky = null;
        String precipitation = null;

        for (JsonNode item : items) {
            if (!targetDateKey.equals(item.path("fcstDate").asText())) {
                continue;
            }
            if (!withinWindow(item.path("fcstTime").asText())) {
                continue;
            }

            String value = item.path("fcstValue").asText();
            switch (item.path("category").asText()) {
                case CATEGORY_WIND_SPEED -> windSpeed = maxOf(windSpeed, toDouble(value));
                case CATEGORY_WAVE_HEIGHT -> waveHeight = maxOf(waveHeight, toDouble(value));
                case CATEGORY_SKY -> sky = worstOf(sky, SKY_LABELS.get(value));
                case CATEGORY_PRECIPITATION_TYPE ->
                        precipitation = worstOf(precipitation, PRECIPITATION_LABELS.get(value));
                default -> {
                    // 나머지 카테고리(TMP·POP·REH…)는 이 화면이 쓰지 않는다
                }
            }
        }

        if (windSpeed == null && sky == null && precipitation == null) {
            throw new KmaApiException("단기예보에 " + targetDateKey + " 출조 시간대 데이터가 없다");
        }

        // 강수가 있으면 하늘상태보다 우선한다 — 비 오는 흐린 날은 '비'다
        String weather = precipitation != null ? precipitation : sky;
        return new KmaForecast(weather, windSpeed, waveHeight);
    }

    private static JsonNode readItems(String body) {
        JsonNode root = PublicApiResponse.readRoot(body, LABEL, KmaApiException::new);

        // 기상청은 header/body 를 response 로 한 번 더 감싼다 (국립해양조사원은 안 감싼다)
        JsonNode header = root.path("response").path("header");
        String resultCode = header.path("resultCode").asText();
        if (!RESULT_CODE_OK.equals(resultCode)) {
            throw new KmaApiException(LABEL + " 오류 resultCode=" + resultCode
                    + " (" + header.path("resultMsg").asText() + ")");
        }

        JsonNode items = root.path("response").path("body").path("items").path("item");
        if (!items.isArray()) {
            throw new KmaApiException(LABEL + " 응답에 item 배열이 없다: "
                    + PublicApiResponse.summarize(body));
        }
        return items;
    }

    private static boolean withinWindow(String fcstTime) {
        if (fcstTime.length() < 2) {
            return false;
        }
        try {
            int hour = Integer.parseInt(fcstTime.substring(0, 2));
            return hour >= WINDOW_START_HOUR && hour <= WINDOW_END_HOUR;
        } catch (NumberFormatException e) {
            return false;
        }
    }

    /** 수치 카테고리에도 '강수없음' 같은 문자열이 섞여 들어온다. 파싱 실패는 그냥 버린다. */
    private static Double toDouble(String value) {
        try {
            return Double.valueOf(value);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static Double maxOf(Double current, Double candidate) {
        if (candidate == null) {
            return current;
        }
        return current == null ? candidate : Math.max(current, candidate);
    }

    private static String worstOf(String current, String candidate) {
        if (candidate == null) {
            return current;
        }
        if (current == null) {
            return candidate;
        }
        return Comparator.comparingInt(WEATHER_SEVERITY::indexOf)
                .compare(candidate, current) > 0 ? candidate : current;
    }
}
