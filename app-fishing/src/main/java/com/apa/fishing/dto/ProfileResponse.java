package com.apa.fishing.dto;

import java.util.List;

/**
 * 마이페이지 (계약서 3-7).
 *
 * <p>계정 자체는 auth-service 가 소유하고 여기 통계만 app-fishing 이 집계한다.
 * 그래서 {@code nickname} 은 DB 가 아니라 <b>토큰에서 온다</b> — 닉네임 하나 때문에
 * 앱 서비스가 auth-service 를 되부르지 않도록 JWT 에 실어 보내고 있다.
 *
 * @param levelTitle 항상 빈 문자열이다. 프론트가 {@code level} 로
 *                   {@code "조사 Lv.7"} 을 조립하므로, 서버가 같은 문구를 또 만들면
 *                   둘이 어긋날 자리만 생긴다. 필드를 지우지 않는 것은 계약서에 있어서다
 */
public record ProfileResponse(
        String nickname,
        int level,
        String levelTitle,
        int catchCount,
        int postCount,
        int favoriteCount,
        List<RegionGroupResponse> favoriteRegions
) {
}
