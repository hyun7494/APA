package com.apa.fishing.dto;

/**
 * {@code POST /fishing/board} — 글쓰기 (계약서 3-8).
 *
 * @param category      2-3 코드({@code CATCH}/{@code FREE}/{@code QUESTION}).
 *                      모르는 값이면 {@code FREE} 로 본다 — 목록 조회(2-3)와 달리 여기서는
 *                      되돌릴 기회가 없어서, 거절하는 대신 기본 게시판에 올린다
 * @param regionGroupId 지역 게시판. 없으면 전체 게시판이다
 */
public record PostCreateRequest(
        String category,
        String title,
        String content,
        Long regionGroupId
) {
}
