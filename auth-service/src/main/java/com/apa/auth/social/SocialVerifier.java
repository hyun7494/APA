package com.apa.auth.social;

import com.apa.auth.domain.SocialType;

/**
 * 소셜 토큰 검증기.
 *
 * <p><b>토큰을 우리가 파싱해서 믿으면 안 된다.</b> 클라이언트가 보낸 문자열은 누구든 만들 수
 * 있으므로 반드시 제공자에게 되물어(또는 서명을 검증해) 확인한다. 이 검증이 로그인 전체의
 * 유일한 신뢰 근거다.
 */
public interface SocialVerifier {

    SocialType supports();

    /**
     * @param token 프론트가 제공자 SDK 로 받은 토큰
     * @return 확인된 신원
     * @throws SocialVerificationException 토큰이 가짜거나, 만료됐거나, 우리 앱 것이 아닐 때
     */
    SocialProfile verify(String token);
}
