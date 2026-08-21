package com.apa.auth.social;

import com.apa.auth.domain.SocialType;

/**
 * 제공자에게서 확인한 신원. <b>여기까지 왔다는 것은 토큰이 진짜라는 뜻이다</b> —
 * 검증에 실패하면 이 값이 만들어지지 않는다.
 *
 * @param nickname   제공자가 안 줄 수 있다 (동의 항목이라). null 이면 가입 시 기본값을 만든다
 * @param profileUrl 마찬가지로 없을 수 있다
 */
public record SocialProfile(
        SocialType socialType,
        String socialId,
        String nickname,
        String profileUrl
) {
}
