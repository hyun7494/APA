package com.apa.auth.social;

import com.apa.auth.domain.SocialType;

/**
 * 제공자에게서 확인한 신원. <b>여기까지 왔다는 것은 토큰이 진짜라는 뜻이다</b> —
 * 검증에 실패하면 이 값이 만들어지지 않는다.
 *
 * @param nickname      제공자가 안 줄 수 있다 (동의 항목이라). null 이면 가입 시 기본값을 만든다
 * @param profileUrl    마찬가지로 없을 수 있다
 * @param email         제공자가 준 주소. 동의하지 않았으면 null 이다
 * @param emailVerified 제공자가 <b>그 주소의 소유를 확인했는지</b>. 계정 연동은 이 값이
 *                      true 일 때만 시작한다 — 확인되지 않은 주소로 계정을 이어 붙이면
 *                      아무 주소나 적어 넣고 남의 계정을 가져갈 수 있다
 */
public record SocialProfile(
        SocialType socialType,
        String socialId,
        String nickname,
        String profileUrl,
        String email,
        boolean emailVerified
) {

    /** 연동에 쓸 수 있는 주소인가. 둘 중 하나라도 빠지면 소셜 신원만으로 판단해야 한다. */
    public boolean hasVerifiedEmail() {
        return emailVerified && email != null && !email.isBlank();
    }
}
