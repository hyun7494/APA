package com.apa.fishing.batch.khoa;

import com.apa.fishing.batch.publicapi.PublicApiResponse;
import com.apa.fishing.domain.Rating;
import com.fasterxml.jackson.databind.JsonNode;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * {@code GetFcstFishingApiServicev2} 응답 → {@link KhoaFishingIndex}. 순수 함수라 키 없이 검증한다.
 *
 * <p><b>봉투가 기상청과 다르다.</b> {@code response} 래퍼 없이 {@code header}/{@code body} 가
 * 최상위다. 기상청 파서를 복사해 쓰면 조용히 빈 결과가 된다.
 *
 * <p>한 행은 <b>(장소 × 날짜 × 오전/오후 × 어종)</b> 하나다. 욕지도 한 곳만 5일 × 2 × 어종 5 = 50행이라
 * {@code numOfRows} 기본값 10 으로는 하루치도 못 채운다.
 *
 * <p>실측 응답(2026-08-12, 욕지도)의 항목명:
 * <pre>
 * seafsPstnNm 장소  predcYmd 예보일  predcNoonSeCd 오전/오후  seafsTgfshNm 대상어종
 * tdlvHrCn 물때     min/maxWvhgt 파고  min/maxWtem 수온  min/maxArtmp 기온
 * min/maxCrsp 유속  min/maxWspd 풍속   totalIndex 종합지수
 * </pre>
 */
public final class FishingIndexParser {

    private FishingIndexParser() {
    }

    private static final String LABEL = "바다낚시지수";
    private static final String RESULT_CODE_OK = "00";

    /** 어종 바구니라 추천으로 내보내면 화면에 '기타어종'이 뜬다. 등급 계산에는 그대로 쓴다. */
    private static final String FISH_OTHERS = "기타어종";

    /**
     * {@code totalIndex} 한글 등급 → {@link Rating}.
     *
     * <p>기관은 5단계라고 안내하는데 실측에서 확인된 건 좋음·보통·나쁨 3개뿐이다.
     * 나머지 둘은 양 끝일 것으로 보고 매핑해 뒀다. 우리 enum 은 4단계라 매우나쁨은 BAD 로 접힌다.
     * 공백 표기 흔들림('매우 좋음')에 대비해 조회 전에 공백을 지운다.
     */
    private static final Map<String, Rating> INDEX_LABELS = Map.of(
            "매우좋음", Rating.VERY_GOOD,
            "좋음", Rating.GOOD,
            "보통", Rating.NORMAL,
            "나쁨", Rating.BAD,
            "매우나쁨", Rating.BAD);

    /** 좋은 쪽이 앞이다. */
    private static final List<Rating> BEST_FIRST =
            List.of(Rating.VERY_GOOD, Rating.GOOD, Rating.NORMAL, Rating.BAD);

    public static KhoaFishingIndex parse(String body, LocalDate targetDate) {
        JsonNode items = readItems(body);
        String targetDateKey = targetDate.toString();   // predcYmd 는 yyyy-MM-dd 다 (기상청과 다르다)

        String placeName = null;
        String tideInfo = null;
        Double minWaterTemp = null;
        Double maxWaterTemp = null;
        Double maxWaveHeight = null;
        Double maxWindSpeed = null;
        Rating best = null;
        List<FishRating> fishRatings = new ArrayList<>();

        for (JsonNode item : items) {
            if (!targetDateKey.equals(item.path("predcYmd").asText())) {
                continue;
            }

            if (placeName == null) {
                placeName = text(item, "seafsPstnNm");
            }
            if (tideInfo == null) {
                tideInfo = text(item, "tdlvHrCn");
            }

            minWaterTemp = minOf(minWaterTemp, number(item, "minWtem"));
            maxWaterTemp = maxOf(maxWaterTemp, number(item, "maxWtem"));
            maxWaveHeight = maxOf(maxWaveHeight, number(item, "maxWvhgt"));
            maxWindSpeed = maxOf(maxWindSpeed, number(item, "maxWspd"));

            Rating rating = toRating(text(item, "totalIndex"));
            if (rating != null) {
                fishRatings.add(new FishRating(text(item, "seafsTgfshNm"), rating));
                best = better(best, rating);
            }
        }

        if (best == null) {
            throw new KhoaApiException(LABEL + "에 " + targetDateKey + " 데이터가 없다");
        }

        return new KhoaFishingIndex(
                placeName,
                best,
                recommendedFish(fishRatings, best),
                midpoint(minWaterTemp, maxWaterTemp),
                maxWaveHeight,
                maxWindSpeed,
                tideInfo);
    }

    private record FishRating(String name, Rating rating) {
    }

    /** 최고 등급을 받은 어종만. 오전·오후로 중복되므로 순서를 지키며 한 번씩만 담는다. */
    private static List<String> recommendedFish(List<FishRating> fishRatings, Rating best) {
        Set<String> names = new LinkedHashSet<>();
        for (FishRating fish : fishRatings) {
            if (fish.rating() == best && !FISH_OTHERS.equals(fish.name())) {
                names.add(fish.name());
            }
        }
        return List.copyOf(names);
    }

    private static JsonNode readItems(String body) {
        JsonNode root = PublicApiResponse.readRoot(body, LABEL, KhoaApiException::new);

        // 국립해양조사원은 response 래퍼가 없다 — header/body 가 최상위다
        JsonNode header = root.path("header");
        String resultCode = header.path("resultCode").asText();
        if (!RESULT_CODE_OK.equals(resultCode)) {
            throw new KhoaApiException(LABEL + " 오류 resultCode=" + resultCode
                    + " (" + header.path("resultMsg").asText() + ")");
        }

        JsonNode items = root.path("body").path("items").path("item");
        if (!items.isArray()) {
            throw new KhoaApiException(LABEL + " 응답에 item 배열이 없다: "
                    + PublicApiResponse.summarize(body));
        }
        return items;
    }

    private static Rating toRating(String label) {
        if (label == null) {
            return null;
        }
        return INDEX_LABELS.get(label.replaceAll("\\s+", ""));
    }

    private static Rating better(Rating current, Rating candidate) {
        if (current == null) {
            return candidate;
        }
        return BEST_FIRST.indexOf(candidate) < BEST_FIRST.indexOf(current) ? candidate : current;
    }

    private static String text(JsonNode item, String field) {
        JsonNode node = item.path(field);
        return node.isMissingNode() || node.isNull() ? null : node.asText();
    }

    /** 수치 필드가 통째로 빠지거나 null 로 오는 행이 있다. 0.0 으로 채우면 안 된다. */
    private static Double number(JsonNode item, String field) {
        JsonNode node = item.path(field);
        return node.isNumber() ? node.asDouble() : null;
    }

    private static Double minOf(Double current, Double candidate) {
        if (candidate == null) {
            return current;
        }
        return current == null ? candidate : Math.min(current, candidate);
    }

    private static Double maxOf(Double current, Double candidate) {
        if (candidate == null) {
            return current;
        }
        return current == null ? candidate : Math.max(current, candidate);
    }

    /** 하루 범위의 중간값. 소수 첫째 자리까지 — 프론트가 '18.4℃' 형태로 렌더한다. */
    private static Double midpoint(Double min, Double max) {
        if (min == null || max == null) {
            return min != null ? min : max;
        }
        return Math.round((min + max) / 2 * 10) / 10.0;
    }
}
