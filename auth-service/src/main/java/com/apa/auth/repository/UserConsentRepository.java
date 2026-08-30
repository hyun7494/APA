package com.apa.auth.repository;

import com.apa.auth.domain.UserConsent;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface UserConsentRepository extends JpaRepository<UserConsent, Long> {

    /**
     * 한 사람의 동의 이력 전부, 최신이 앞이다.
     *
     * <p>현재 상태만 뽑는 질의를 두지 않는다 — 이력을 다 읽어 (항목별 첫 행)을 고르는
     * 편이 이 규모에서는 단순하고, 무엇보다 <b>철회 이력이 보이는 채로</b> 다룬다.
     * 한 사람의 동의는 많아야 열 몇 건이다.
     */
    List<UserConsent> findByUserIdOrderByAgreedAtDescIdDesc(Long userId);
}
