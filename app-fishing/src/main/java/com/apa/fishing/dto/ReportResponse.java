package com.apa.fishing.dto;

/**
 * 신고 결과.
 *
 * <p><b>신고가 몇 건 쌓였는지는 알려주지 않는다.</b> 좋아요와 다른 점이다 — 그 수가 보이면
 * "몇 건이면 글이 내려가는지" 를 재 볼 수 있고, 여럿이 맞춰서 특정 글을 노리는 데 쓰인다.
 *
 * @param alreadyReported 이미 신고해 둔 글이었나. 두 번째 신고를 오류로 내지 않고
 *                        이 값으로 구분한다 — 사용자 입장에서 결과(신고됨)는 같다
 */
public record ReportResponse(boolean alreadyReported) {
}
