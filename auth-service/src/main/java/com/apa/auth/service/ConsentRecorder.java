package com.apa.auth.service;

import com.apa.common.time.Kst;
import com.apa.auth.domain.ConsentType;
import com.apa.auth.domain.UserConsent;
import com.apa.auth.dto.ConsentRequest;
import com.apa.auth.exception.BadRequestException;
import com.apa.auth.repository.UserConsentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;

/**
 * 가입 요청에 실려 온 동의를 <b>검사하고 기록한다.</b>
 *
 * <p>{@link AuthService} 에서 떼어 낸 이유는 검사 규칙이 법에서 오는 것이라 가입 절차와
 * 수명이 다르기 때문이다 — 항목이 늘거나 필수/선택이 바뀌는 일은 여기서만 일어난다.
 */
@Component
@RequiredArgsConstructor
public class ConsentRecorder {

    private final UserConsentRepository consentRepository;

    /**
     * 필수 항목이 전부 동의됐는지 보고, 받은 것을 그대로 남긴다.
     *
     * <p>★ <b>화면에서 막았으니 서버는 안 봐도 된다고 볼 수 없다.</b> 가입 API 는 앱 없이도
     * 부를 수 있고, 동의는 나중에 증명해야 하는 종류의 기록이다. 여기가 마지막 방어선이다.
     *
     * <p>선택 항목은 {@code false} 로 와도 통과시킨다 — 선택 동의를 가입 조건으로 걸면
     * 그건 동의가 아니라 강요다.
     *
     * <p><b>거부한 선택 항목도 행으로 남긴다.</b> "묻지 않았다" 와 "물었고 거절했다" 는
     * 다른 사실이고, 나중에 마케팅을 보낼 때 그 둘을 구별할 수 있어야 한다.
     *
     * @throws BadRequestException 필수 항목이 빠졌거나 false 이거나, 모르는 코드가 왔을 때
     */
    public void recordForSignUp(Long userId, List<ConsentRequest> consents) {
        Map<ConsentType, ConsentRequest> received = parse(consents);

        List<String> missing = ConsentType.required().stream()
                .filter(type -> {
                    ConsentRequest given = received.get(type);
                    return given == null || !given.agreed();
                })
                .map(Enum::name)
                .toList();
        if (!missing.isEmpty()) {
            throw new BadRequestException("필수 동의 항목이 빠졌습니다: " + String.join(", ", missing));
        }

        LocalDateTime now = Kst.now();
        List<UserConsent> rows = new ArrayList<>(received.size());
        received.forEach((type, given) -> rows.add(
                UserConsent.record(userId, type, version(given), given.agreed(), now)));
        consentRepository.saveAll(rows);
    }

    private static Map<ConsentType, ConsentRequest> parse(List<ConsentRequest> consents) {
        Map<ConsentType, ConsentRequest> parsed = new EnumMap<>(ConsentType.class);
        if (consents == null) {
            return parsed;
        }
        for (ConsentRequest consent : consents) {
            if (consent == null || consent.type() == null) {
                throw new BadRequestException("동의 항목이 비어 있습니다");
            }
            try {
                // 같은 항목이 두 번 오면 뒤엣것을 쓴다. 앱이 그럴 일은 없지만
                // 조용히 둘 다 넣으면 "현재 상태" 가 뭔지 알 수 없어진다.
                parsed.put(ConsentType.of(consent.type()), consent);
            } catch (IllegalArgumentException e) {
                throw new BadRequestException(e.getMessage());
            }
        }
        return parsed;
    }

    /** 판을 안 보내면 기록할 수 없다 — "뭐에 동의했는지" 를 잃는다. */
    private static String version(ConsentRequest consent) {
        if (consent.version() == null || consent.version().isBlank()) {
            throw new BadRequestException("동의한 문서의 판(version)이 없습니다: " + consent.type());
        }
        return consent.version().trim();
    }
}
