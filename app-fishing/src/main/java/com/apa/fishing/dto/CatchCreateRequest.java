package com.apa.fishing.dto;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;

/**
 * 조과 등록·수정 요청. multipart/form-data 의 텍스트 필드를 모은 것이다 (사진은 별도 파트).
 *
 * <p>정규화를 컨트롤러가 아니라 여기서 하는 이유: 이 규칙들이 <b>순수 함수라 테스트된다.</b>
 * 컨트롤러에 흩어 두면 검증을 확인하려고 서블릿을 띄워야 한다.
 *
 * <p><b>어종과 길이는 검증하지 않는다</b> — Rev 2 에서 자동 판별·자동 측정을 걷어냈으므로 둘 다
 * 자기신고이고 서버에 검증할 근거가 없다. 여기서 막는 건 <b>컬럼에 안 들어가는 값</b>뿐이다.
 * 금지체장 미만은 정상 등록이고, 안내는 프론트가 배너로 한다 (기획서 5-4 ③).
 */
public record CatchCreateRequest(
        Long speciesId,
        BigDecimal lengthCm,
        Integer weightG,
        LocalDateTime caughtAt,
        Long regionGroupId,
        String spotName,
        String memo
) {

    /** DECIMAL(4,1) — 소수점 앞자리가 셋이다. */
    private static final BigDecimal MAX_LENGTH = new BigDecimal("999.9");
    private static final int SPOT_NAME_LIMIT = 50;    // VARCHAR(50)
    private static final int MEMO_LIMIT = 300;        // VARCHAR(300)

    public static CatchCreateRequest of(Long speciesId, Double lengthCm, Integer weightG,
                                        String caughtAt, Long regionGroupId,
                                        String spotName, String memo) {
        if (speciesId == null) {
            throw badRequest("어종을 선택해주세요");
        }
        return new CatchCreateRequest(
                speciesId,
                normalizeLength(lengthCm),
                weightG,
                parseCaughtAt(caughtAt),
                regionGroupId,
                limit(spotName, SPOT_NAME_LIMIT, "장소"),
                limit(memo, MEMO_LIMIT, "메모")
        );
    }

    /**
     * 소수점 1자리로 맞춘다 (프론트도 1자리 입력이다). 반올림하지 않고 그대로 넣으면
     * 스케일 초과로 INSERT 가 터지는데, 그 500 을 보고 원인이 길이라는 걸 알아보기 어렵다.
     */
    private static BigDecimal normalizeLength(Double lengthCm) {
        if (lengthCm == null || lengthCm.isNaN() || lengthCm <= 0) {
            throw badRequest("길이를 입력해주세요");
        }
        BigDecimal value = BigDecimal.valueOf(lengthCm).setScale(1, RoundingMode.HALF_UP);
        if (value.compareTo(MAX_LENGTH) > 0) {
            throw badRequest("길이는 %scm 까지 입력할 수 있습니다".formatted(MAX_LENGTH.toPlainString()));
        }
        return value;
    }

    /**
     * 프론트는 {@code DateTime.toIso8601String()} 을 보낸다 — 기기 로컬 시각이라 보통
     * {@code 2026-08-17T14:30:00.000} 처럼 오프셋이 없다. 다만 UTC 로 만든 DateTime 이면
     * {@code Z} 가 붙어서 나오므로 <b>두 형태를 다 받는다.</b> 여기서 400 을 내면 사용자는
     * 사진·길이를 다 채워 놓고 등록만 안 되는 상태에 빠진다 — 못 읽으면 현재 시각으로 떨어뜨린다.
     */
    private static LocalDateTime parseCaughtAt(String caughtAt) {
        if (caughtAt == null || caughtAt.isBlank()) {
            return LocalDateTime.now();
        }
        String value = caughtAt.trim();
        try {
            return LocalDateTime.parse(value);
        } catch (DateTimeParseException ignored) {
            // 오프셋이 붙은 형태로 다시 시도한다
        }
        try {
            return OffsetDateTime.parse(value).toLocalDateTime();
        } catch (DateTimeParseException ignored) {
            // Instant("...Z") 로 다시 시도한다
        }
        try {
            return LocalDateTime.ofInstant(Instant.parse(value), ZoneId.systemDefault());
        } catch (DateTimeParseException ignored) {
            return LocalDateTime.now();
        }
    }

    /**
     * 컬럼 길이를 넘으면 <b>자르지 않고 거절한다.</b> 지수 코멘트({@code SpotComment})는 잘라 쓰지만
     * 저건 우리가 만든 문구고 이건 사용자가 쓴 글이다 — 조용히 잘라 저장하면 사용자는 자기 메모가
     * 언제 사라졌는지 모른다.
     */
    private static String limit(String value, int max, String label) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        if (trimmed.isEmpty()) {
            return null;   // 빈 문자열을 넣어 두면 "없음"과 "비워 둠"이 섞인다
        }
        if (trimmed.length() > max) {
            throw badRequest("%s는 %d자까지 입력할 수 있습니다".formatted(label, max));
        }
        return trimmed;
    }

    private static ResponseStatusException badRequest(String message) {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, message);
    }
}
