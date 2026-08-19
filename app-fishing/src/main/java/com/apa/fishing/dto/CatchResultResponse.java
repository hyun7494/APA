package com.apa.fishing.dto;

import com.apa.fishing.domain.CatchRecord;

/**
 * 조과 등록 응답 (기획서 v2 4-2).
 *
 * <p><b>{@code firstCatch} 는 서버가 판단해서 내려준다.</b> 이 값으로 프론트가 도감 획득 연출을
 * 재생할지 정하는데, 클라이언트가 "내 도감에 있었나"를 재조회로 판단하면 등록과 조회 사이에
 * 경합이 생겨 연출이 빠지거나 두 번 뜬다.
 *
 * <p>진행도({@code ownedCount}/{@code totalCount})를 함께 실어 보내는 이유도 같다 — 등록 직후
 * 화면이 "13번째 칸이 채워졌습니다"를 그리려면 갱신된 분자·분모가 그 자리에 있어야 한다.
 */
public record CatchResultResponse(
        CatchResponse record,
        boolean firstCatch,
        long ownedCount,
        long totalCount
) {

    public static CatchResultResponse of(CatchRecord saved, boolean firstCatch,
                                         long ownedCount, long totalCount) {
        return new CatchResultResponse(CatchResponse.from(saved), firstCatch, ownedCount, totalCount);
    }
}
