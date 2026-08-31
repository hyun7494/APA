package com.apa.auth.repository;

import com.apa.auth.domain.SocialType;
import com.apa.auth.domain.UserSocialAccount;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserSocialAccountRepository extends JpaRepository<UserSocialAccount, Long> {

    /** 로그인 판정. {@code (social_type, social_id)} 에 UNIQUE 가 걸려 있다. */
    Optional<UserSocialAccount> findBySocialTypeAndSocialId(SocialType socialType, String socialId);

    /** 연동 판정 — 이 사람이 이 제공자를 이미 붙였는가. */
    Optional<UserSocialAccount> findByUserIdAndSocialType(Long userId, SocialType socialType);

    /** 탈퇴 — 제공자 식별자는 개인정보라 남기지 않는다. */
    void deleteByUserId(Long userId);
}
