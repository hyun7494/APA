package com.apa.fishing.domain;

/**
 * 어종 희귀 등급 (기획서 v2 3-2). RARE 인 칸만 도감에서 골드 테두리를 두른다.
 *
 * <p>등록 빈도로 자동 산출하지 않고 <b>어종 마스터에 수동 지정</b>한다 — 조과가 자기신고
 * 데이터라 빈도를 등급으로 바꾸면 허위 등록이 등급을 흔든다.
 */
public enum Rarity {
    COMMON, UNCOMMON, RARE
}
