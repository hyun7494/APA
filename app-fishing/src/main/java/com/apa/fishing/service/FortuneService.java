package com.apa.fishing.service;

import com.apa.fishing.batch.FortuneGenerator;
import com.apa.fishing.domain.DailyFortune;
import com.apa.fishing.domain.Zodiac;
import com.apa.fishing.dto.FortuneResponse;
import com.apa.fishing.repository.DailyFortuneRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j
public class FortuneService {

    private final DailyFortuneRepository fortuneRepository;
    private final FortuneGenerator fortuneGenerator;

    /**
     * 오늘 치가 없으면 <b>그 자리에서 하루치를 만들어</b> 응답한다.
     * 개발 노트북에서는 00:10 배치가 뜰 일이 거의 없어서, 실질적으로 이 경로가 하루치를 채운다.
     *
     * <p>클래스에 {@code @Transactional(readOnly = true)} 를 걸지 않은 이유가 있다 —
     * 읽기 전용 트랜잭션 안에서 생성기를 부르면 같은 트랜잭션에 합류해 INSERT 가 거부된다.
     */
    public FortuneResponse findToday(String zodiacCode) {
        Zodiac zodiac = Zodiac.fromCode(zodiacCode);
        LocalDate today = LocalDate.now(FortuneGenerator.KST);

        Optional<DailyFortune> found = fortuneRepository.findByFortuneDateAndZodiac(today, zodiac);
        if (found.isEmpty()) {
            generateQuietly(today);
            found = fortuneRepository.findByFortuneDateAndZodiac(today, zodiac);
        }

        return found
                // 생성까지 실패해도 화면은 비우지 않는다.
                .or(() -> fortuneRepository.findFirstByZodiacOrderByFortuneDateDesc(zodiac))
                .map(FortuneResponse::from)
                // 프론트가 res.data! 로 단정해 읽으므로 404나 빈 본문은 화면을 죽인다.
                .orElseGet(() -> FortuneResponse.empty(zodiac, today));
    }

    /**
     * 12띠 첫 조회가 동시에 들어오면 두 요청이 같은 날짜를 만들려 할 수 있다.
     * {@code UNIQUE(fortune_date, zodiac)} 가 막아주므로, 진 쪽은 그냥 다시 읽으면 된다.
     * (생성기 안에서 잡으면 트랜잭션이 rollback-only 로 표시돼 커밋 시 터진다 — 여기서 잡는다)
     */
    private void generateQuietly(LocalDate date) {
        try {
            fortuneGenerator.generateIfAbsent(date);
        } catch (DataIntegrityViolationException e) {
            log.debug("{} 운세를 다른 요청이 먼저 만들었다", date);
        }
    }
}
