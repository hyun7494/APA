package com.apa.auth.repository;

import com.apa.auth.domain.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {

    /**
     * 이메일 로그인과 계정 연동의 출발점.
     *
     * <p>넘기는 값은 <b>정규화(소문자)된 주소</b>여야 한다. 컬럼 UNIQUE 는 대소문자를
     * 구분하므로, 정규화하지 않고 넣으면 같은 주소로 계정이 두 개 생긴다.
     */
    Optional<User> findByEmail(String email);
}
