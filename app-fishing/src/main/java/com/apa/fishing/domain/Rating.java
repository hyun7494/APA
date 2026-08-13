package com.apa.fishing.domain;

/**
 * 낚시 지수 등급 (계약서 2-1). 프론트가 이 대문자 코드로 배지를 고른다.
 * 매칭 실패 시 조용히 NORMAL 로 떨어지므로 한글 라벨을 넣으면 안 된다.
 */
public enum Rating {

    /** <b>선언 순서가 좋은 것 → 나쁜 것이다.</b> {@link #worse} 가 이 순서에 기댄다 — 섞지 말 것. */
    VERY_GOOD, GOOD, NORMAL, BAD;

    /**
     * 둘 중 나쁜 쪽. 안전 관련 판단에서 두 출처가 엇갈릴 때 쓴다.
     *
     * <p>한쪽이 {@code null} 이면 다른 쪽을 그대로 준다 — 값이 없는 것은 "좋다"는 뜻이 아니므로
     * 비교에서 빼는 것이지, 좋은 쪽으로 치는 게 아니다.
     */
    public static Rating worse(Rating a, Rating b) {
        if (a == null) {
            return b;
        }
        if (b == null) {
            return a;
        }
        return a.ordinal() >= b.ordinal() ? a : b;
    }
}
