package com.apa.fishing.domain;

import java.util.Locale;

/**
 * 12지신. DB·응답 모두 이 대문자 코드를 그대로 쓴다 (계약서 2-2).
 * 한글 라벨을 넣으면 프론트 {@code Zodiac.fromCode} 가 전부 RAT 으로 매칭해
 * 12띠가 같은 운세로 보인다.
 */
public enum Zodiac {
    RAT, OX, TIGER, RABBIT, DRAGON, SNAKE, HORSE, GOAT, MONKEY, ROOSTER, DOG, PIG;

    /** 프론트와 같은 규칙 — 모르는 값이면 조용히 RAT 으로 떨어진다. */
    public static Zodiac fromCode(String code) {
        if (code == null || code.isBlank()) {
            return RAT;
        }
        try {
            return valueOf(code.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            return RAT;
        }
    }
}
