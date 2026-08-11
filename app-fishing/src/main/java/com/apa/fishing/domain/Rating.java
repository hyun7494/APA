package com.apa.fishing.domain;

/**
 * 낚시 지수 등급 (계약서 2-1). 프론트가 이 대문자 코드로 배지를 고른다.
 * 매칭 실패 시 조용히 NORMAL 로 떨어지므로 한글 라벨을 넣으면 안 된다.
 */
public enum Rating {
    VERY_GOOD, GOOD, NORMAL, BAD
}
