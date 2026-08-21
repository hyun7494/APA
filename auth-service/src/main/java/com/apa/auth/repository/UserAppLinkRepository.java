package com.apa.auth.repository;

import com.apa.auth.domain.UserAppLink;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserAppLinkRepository extends JpaRepository<UserAppLink, UserAppLink.Key> {

    Optional<UserAppLink> findByUserIdAndAppId(Long userId, String appId);
}
