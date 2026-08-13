package com.apa.fishing.batch;

import com.apa.fishing.domain.Rating;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * 포인트 카드에 뜨는 한 줄 코멘트. 순수 함수라 키 없이 검증한다.
 *
 * <p><b>왜 등급을 안 낮추고 문구로 처리하나.</b> 두 기준이 보는 게 다르다 —
 * KHOA {@code totalIndex} 는 <b>어종이 물느냐</b>를, {@link RatingRule} 은 <b>나가도 되느냐</b>
 * (파고·풍속)를 말한다. 등급을 나쁜 쪽으로 덮으면 "고기는 무는데 배지는 나쁨"이 되어
 * 어황 정보가 사라지고, 실제로 6곳 중 4곳이 떨어져 지수 자체가 무의미해졌다.
 * 그래서 <b>등급은 어황 그대로 두고, 안전은 문구로 따로 말한다.</b>
 *
 * <p>문구에는 <b>실제 수치를 박는다</b>("바람이 셉니다"가 아니라 "풍속 8.3㎧"). 두루뭉술한
 * 경고는 읽는 사람이 판단할 근거가 못 된다. 컬럼이 VARCHAR(200) 이라 길이도 여기서 맞춘다.
 *
 * <p>⚠️ 상세 화면에는 별도로 면책 문구가 고정 노출돼 있다
 * ("참고용 정보이며 실제 출조 여부는 현장 상황을 확인하세요"). 여기 문구는 그걸 대신하지 않는다.
 */
public final class SpotComment {

    private SpotComment() {
    }

    /** 컬럼이 VARCHAR(200) 이다. 넘치면 INSERT 가 터진다. */
    private static final int MAX_LENGTH = 200;

    private static final double STRONG_WIND = 8.0;
    private static final double HIGH_WAVE = 1.5;

    /**
     * @param rating     KHOA 어황 등급 (그대로 유지된다)
     * @param waveHeight 하루 최대 파고. 없으면 null
     * @param windSpeed  하루 최대 풍속. 없으면 null
     * @param weather    기상청 날씨 표기. 없으면 null
     */
    public static String describe(Rating rating, Double waveHeight, Double windSpeed, String weather) {
        if (waveHeight == null || windSpeed == null) {
            return byRating(rating);
        }

        Rating safety = RatingRule.evaluate(waveHeight, windSpeed, weather);

        // 경고는 두 조건을 모두 만족할 때만 붙인다.
        //
        //  ① 안전 기준이 어황 등급보다 나쁘다 — 이미 등급이 낮으면 겹쳐 말하지 않는다
        //  ② 그 안전 기준 자체가 NORMAL 이하다
        //
        // ②가 없으면 오경보가 난다. KHOA 가 VERY_GOOD 을 준 날은 한 칸만 어긋나도 ①에 걸려서,
        // 실제로 돌산 갯바위가 **파고 0.3m · 풍속 4.3㎧ 인데** 경고를 달았다. 잔잔한 날이다.
        // 경고가 흔해지면 정작 거친 날에 읽히지 않는다.
        boolean worseThanRating = Rating.worse(rating, safety) != rating;
        boolean roughEnough = safety == Rating.NORMAL || safety == Rating.BAD;

        if (!worseThanRating || !roughEnough) {
            return byRating(rating);
        }

        return truncate(warning(rating, waveHeight, windSpeed, weather));
    }

    /**
     * 강한 표현("출조를 권하지 않습니다")은 <b>등급 하락이 아니라 실제 임계값</b>에 건다.
     *
     * <p>{@link RatingRule} 의 강수 페널티는 한 단계를 통째로 깎아서, 파고 0.7m · 풍속 5.6㎧ 에
     * 소나기만 얹혀도 등급이 BAD 까지 간다. 그 수준에 "나가지 마라"라고 하면 문구가 과해지고,
     * 과한 경고가 반복되면 정작 <b>진짜 위험한 날에 아무도 안 읽는다.</b>
     * 그래서 만류는 강풍·높은 너울일 때만 하고, 나머지는 주의 환기에 그친다.
     */
    private static String warning(Rating rating, double waveHeight, double windSpeed, String weather) {
        String conditions = String.join(", ", drivers(waveHeight, windSpeed, weather));

        if (windSpeed >= STRONG_WIND || waveHeight >= HIGH_WAVE) {
            return "%s. 어종 활성도는 '%s'이나 기상이 거칠어 출조를 권하지 않습니다."
                    .formatted(conditions, label(rating));
        }
        return "%s. 어황은 '%s'이나 안전에 유의하세요.".formatted(conditions, label(rating));
    }

    /** 무엇 때문에 경고가 붙었는지 수치로 남긴다. 이걸 빼면 "왜 나쁘다는 건데"가 된다. */
    private static List<String> drivers(double waveHeight, double windSpeed, String weather) {
        List<String> drivers = new ArrayList<>();

        if (windSpeed >= STRONG_WIND) {
            drivers.add("풍속 %s㎧의 강풍".formatted(number(windSpeed)));
        } else {
            drivers.add("풍속 %s㎧".formatted(number(windSpeed)));
        }

        if (waveHeight >= HIGH_WAVE) {
            drivers.add("파고 %sm의 높은 너울".formatted(number(waveHeight)));
        } else {
            drivers.add("파고 %sm".formatted(number(waveHeight)));
        }

        if (RatingRule.isPrecipitation(weather)) {
            drivers.add(weather.trim());
        }
        return drivers;
    }

    private static String byRating(Rating rating) {
        if (rating == null) {
            return "";
        }
        return switch (rating) {
            case VERY_GOOD -> "바람 약하고 파고 낮아 출조하기 아주 좋은 날입니다.";
            case GOOD -> "무난한 조건입니다. 물때를 보아 출조해볼 만합니다.";
            case NORMAL -> "특별히 나쁘진 않으나 기대만큼의 조황은 어려울 수 있습니다.";
            case BAD -> "어종 활성도가 낮아 조황을 기대하기 어렵습니다.";
        };
    }

    private static String label(Rating rating) {
        if (rating == null) {
            return "-";
        }
        return switch (rating) {
            case VERY_GOOD -> "매우 좋음";
            case GOOD -> "좋음";
            case NORMAL -> "보통";
            case BAD -> "나쁨";
        };
    }

    /** 소수 첫째 자리까지. 8.0 을 "8"로 줄이면 관측값이 아니라 어림수처럼 보인다. */
    private static String number(double value) {
        return String.format(Locale.ROOT, "%.1f", value);
    }

    private static String truncate(String text) {
        return text.length() <= MAX_LENGTH ? text : text.substring(0, MAX_LENGTH - 1) + "…";
    }
}
