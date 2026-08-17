package com.apa.fishing.domain;

/**
 * 어종 서식지 (기획서 v2 3-2). 프론트 {@code Habitat.fromCode} 가 이 대문자 코드로 매칭하며,
 * 매칭 실패 시 조용히 SEA 로 떨어진다 — 한글 라벨을 넣으면 민물 어종이 전부 바다로 보인다.
 */
public enum Habitat {
    SEA, FRESH
}
