package com.apa.auth.repository;

import com.apa.auth.domain.SocialType;
import com.apa.auth.domain.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {

    /** 가입 여부 판정. {@code (social_type, social_id)} 에 UNIQUE 가 걸려 있다. */
    Optional<User> findBySocialTypeAndSocialId(SocialType socialType, String socialId);
}
