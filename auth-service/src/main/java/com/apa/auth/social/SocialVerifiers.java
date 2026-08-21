package com.apa.auth.social;

import com.apa.auth.domain.SocialType;
import org.springframework.stereotype.Component;

import java.util.EnumMap;
import java.util.List;
import java.util.Map;

/**
 * {@link SocialType} → 검증기.
 *
 * <p>제공자를 늘릴 때 {@link SocialVerifier} 구현 하나만 추가하면 스프링이 주입해 준다.
 * switch 문을 여기저기 두면 새 제공자를 붙일 때 빠뜨리는 자리가 생긴다.
 */
@Component
public class SocialVerifiers {

    private final Map<SocialType, SocialVerifier> byType = new EnumMap<>(SocialType.class);

    public SocialVerifiers(List<SocialVerifier> verifiers) {
        for (SocialVerifier verifier : verifiers) {
            byType.put(verifier.supports(), verifier);
        }
    }

    public SocialVerifier get(SocialType type) {
        SocialVerifier verifier = byType.get(type);
        if (verifier == null) {
            throw new SocialVerificationException("지원하지 않는 로그인 방식입니다: " + type);
        }
        return verifier;
    }
}
