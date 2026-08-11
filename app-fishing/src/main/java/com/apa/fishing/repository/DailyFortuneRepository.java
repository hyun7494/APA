package com.apa.fishing.repository;

import com.apa.fishing.domain.DailyFortune;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.Optional;

public interface DailyFortuneRepository extends JpaRepository<DailyFortune, Long> {

    Optional<DailyFortune> findByFortuneDateAndZodiac(LocalDate fortuneDate, String zodiac);

    /** 오늘 치가 아직 없을 때(배치 미구현 기간) 쓰는 대체 조회. */
    Optional<DailyFortune> findFirstByZodiacOrderByFortuneDateDesc(String zodiac);
}
