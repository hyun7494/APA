package com.apa.fishing.repository;

import com.apa.fishing.domain.DailyFortune;
import com.apa.fishing.domain.Zodiac;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.Optional;

public interface DailyFortuneRepository extends JpaRepository<DailyFortune, Long> {

    Optional<DailyFortune> findByFortuneDateAndZodiac(LocalDate fortuneDate, Zodiac zodiac);

    /** 배치·폴백 생성의 재실행 안전장치. 12띠를 한 트랜잭션에 넣으므로 날짜 단위로만 보면 된다. */
    boolean existsByFortuneDate(LocalDate fortuneDate);

    /** 생성까지 실패했을 때 화면을 비우지 않기 위한 최후 대체 조회. */
    Optional<DailyFortune> findFirstByZodiacOrderByFortuneDateDesc(Zodiac zodiac);
}
