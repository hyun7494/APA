package com.apa.fishing.service;

import com.apa.fishing.dto.FortuneResponse;
import com.apa.fishing.repository.DailyFortuneRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.Locale;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class FortuneService {

    /** 프론트 Zodiac.fromCode 의 기본값과 맞춘다. */
    private static final String DEFAULT_ZODIAC = "RAT";

    private final DailyFortuneRepository fortuneRepository;

    /**
     * 오늘 치가 없으면 가장 최근 날짜로 대체한다. Step 7 운세 배치가 붙기 전까지는
     * V2 시드가 적용된 날짜의 운세만 존재하기 때문에, 그대로 두면 다음 날부터 화면이 빈다.
     */
    public FortuneResponse findToday(String zodiac) {
        String code = normalize(zodiac);
        LocalDate today = LocalDate.now();

        return fortuneRepository.findByFortuneDateAndZodiac(today, code)
                .or(() -> fortuneRepository.findFirstByZodiacOrderByFortuneDateDesc(code))
                .map(FortuneResponse::from)
                .orElseGet(() -> FortuneResponse.empty(code, today));
    }

    private static String normalize(String zodiac) {
        if (zodiac == null || zodiac.isBlank()) {
            return DEFAULT_ZODIAC;
        }
        return zodiac.trim().toUpperCase(Locale.ROOT);
    }
}
