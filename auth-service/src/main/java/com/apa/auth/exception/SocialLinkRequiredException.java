package com.apa.auth.exception;

import com.apa.auth.domain.SocialType;

/**
 * 소셜로 처음 들어왔는데 <b>같은 이메일의 자체 가입 계정이 이미 있는</b> 경우.
 *
 * <p>여기서 그냥 이어 붙이면 안 된다. 우리는 자체 가입 이메일의 소유를 확인하지 못한다 —
 * 남의 주소로 먼저 가입해 둔 사람이, 진짜 주인이 카카오로 들어오는 순간 그 사람을 자기
 * 계정 안으로 끌어들일 수 있다. 그래서 <b>비밀번호를 한 번 받아</b> 두 신원이 같은 사람의
 * 것임을 확인한 뒤 붙인다.
 *
 * <p>새 계정을 따로 만드는 선택지도 있지만 그러면 도감·조과가 둘로 쪼개진다.
 * 사용자가 원한 것은 "내 계정으로 들어가기"다.
 */
public class SocialLinkRequiredException extends RuntimeException {

    /** 프론트가 문자열 대신 이 값으로 분기한다. 문구는 바뀌어도 코드는 안 바뀐다. */
    public static final String CODE = "LINK_REQUIRED";

    private final String email;
    private final SocialType provider;

    public SocialLinkRequiredException(String email, SocialType provider) {
        super("이미 이 이메일로 가입한 계정이 있습니다. 비밀번호를 입력하면 계정을 연결합니다");
        this.email = email;
        this.provider = provider;
    }

    public String getEmail() {
        return email;
    }

    public SocialType getProvider() {
        return provider;
    }
}
