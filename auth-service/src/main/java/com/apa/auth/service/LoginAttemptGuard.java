package com.apa.auth.service;

import com.apa.auth.exception.TooManyAttemptsException;
import com.apa.common.time.Kst;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * 로그인 무차별 대입을 늦춘다.
 *
 * <p>★ <b>아무것도 없었다.</b> 틀린 비밀번호로 60번을 연속으로 시도해도 전부 401 이 나오고
 * 잠금도 지연도 없었으며, 그 뒤 맞는 비밀번호가 그대로 통했다. bcrypt 덕에 초당 16회쯤으로
 * 자연히 눌리기는 하지만, 연결을 여러 개 열면 그 한계도 같이 늘어난다. 흔한 비밀번호를
 * 쓰는 계정에는 그 속도로도 충분하다.
 *
 * <p><b>계정과 출발지를 함께 센다.</b> 계정만 세면 한 사람이 여러 계정을 훑는 것을 못 잡고,
 * 출발지만 세면 공유 IP(회사·학교) 뒤의 애먼 사람들이 같이 막힌다.
 *
 * <p>⚠️ <b>메모리에 센다. 인스턴스가 하나일 때만 온전하다.</b> 여러 대로 늘리면 대수만큼
 * 한도가 늘어나므로, 그때는 Redis 같은 공유 저장소로 옮기거나 앞단(WAF·게이트웨이)에
 * 맡겨야 한다. 지금 한 대인데 아무 제한도 없는 것보다는 낫다는 판단이다.
 */
@Slf4j
@Component
public class LoginAttemptGuard {

    /** 한 계정에 허용하는 연속 실패. 오타 몇 번은 통과해야 한다. */
    private final int maxPerAccount;

    /**
     * 한 출발지에 허용하는 연속 실패. <b>계정 쪽보다 훨씬 넉넉하다.</b>
     *
     * <p>⚠️ 같은 값을 쓰면 <b>공유 IP 뒤의 애먼 사람들이 같이 막힌다</b> — 회사·학교·통신사
     * NAT 뒤에서는 남이 비밀번호를 몇 번 틀렸다는 이유로 내가 못 들어간다. 실제로 이걸
     * 하나로 뒀다가 테스트가 무더기로 깨졌는데, 그게 바로 그 증상이었다.
     *
     * <p>출발지 칸의 목적은 한 사람이 <b>여러 계정을 훑는 것</b>을 잡는 것이지 한 계정을
     * 지키는 게 아니다. 그건 계정 칸이 한다.
     */
    private final int maxPerIp;

    /** 잠기는 시간. 사람에게는 잠깐이고 자동 대입에는 치명적인 길이. */
    private final Duration lockout;

    /**
     * 세는 칸의 상한.
     *
     * <p>⚠️ <b>이게 없으면 방어 장치가 그 자체로 공격 수단이 된다</b> — 매번 다른 이메일로
     * 두드리면 칸이 무한히 늘어 메모리가 바닥난다. 넘치면 통째로 비운다. 그 순간
     * 세던 것을 잃지만, 서버가 죽는 것보다 낫다.
     */
    private static final int MAX_TRACKED = 100_000;

    private final Map<String, Counter> counters = new ConcurrentHashMap<>();

    public LoginAttemptGuard(
            @Value("${auth.login.max-failures:10}") int maxPerAccount,
            @Value("${auth.login.max-failures-per-ip:100}") int maxPerIp,
            @Value("${auth.login.lockout-seconds:300}") long lockoutSeconds) {
        this.maxPerAccount = maxPerAccount;
        this.maxPerIp = maxPerIp;
        this.lockout = Duration.ofSeconds(lockoutSeconds);
    }

    /**
     * 시도해도 되는지 본다.
     *
     * @throws TooManyAttemptsException 잠긴 동안
     */
    public void check(String email, String clientIp) {
        for (String key : keysOf(email, clientIp)) {
            Counter counter = counters.get(key);
            if (counter != null && counter.lockedUntil != null
                    && counter.lockedUntil.isAfter(Kst.now())) {
                throw new TooManyAttemptsException(
                        "로그인 시도가 너무 많습니다. 잠시 후 다시 시도해 주세요");
            }
        }
    }

    /** 실패를 센다. 한도를 넘으면 잠근다. */
    public void recordFailure(String email, String clientIp) {
        if (counters.size() > MAX_TRACKED) {
            log.warn("로그인 시도 집계가 {}칸을 넘어 비운다 — 여러 계정을 훑는 시도일 수 있다", MAX_TRACKED);
            counters.clear();
        }
        String[] keys = keysOf(email, clientIp);
        int[] limits = {maxPerAccount, maxPerIp};
        for (int i = 0; i < keys.length; i++) {
            Counter counter = counters.computeIfAbsent(keys[i], k -> new Counter());
            if (counter.failures.incrementAndGet() >= limits[i]) {
                counter.lockedUntil = Kst.now().plus(lockout);
                counter.failures.set(0);
                log.warn("로그인 시도 초과로 {}분간 잠근다: {}", lockout.toMinutes(), keys[i]);
            }
        }
    }

    /**
     * 성공하면 지운다.
     *
     * <p>비밀번호를 맞힌 사람은 주인이므로, 그 전에 오타를 몇 번 냈든 다음 로그인이
     * 깨끗한 상태에서 시작해야 한다.
     */
    public void recordSuccess(String email, String clientIp) {
        for (String key : keysOf(email, clientIp)) {
            counters.remove(key);
        }
    }

    /**
     * 세던 것을 전부 비운다.
     *
     * <p>⚠️ <b>테스트 전용이다.</b> 요청 처리 중에 부르면 그 순간 잠금이 풀려서 이 방어
     * 장치가 통째로 무력해진다. 공개인 이유는 테스트가 다른 패키지에 있어서일 뿐이다.
     */
    public void clear() {
        counters.clear();
    }

    /**
     * 계정 칸과 출발지 칸. <b>순서가 위 limits 배열과 맞아야 한다.</b>
     *
     * <p>이메일은 정규화한 것을 쓴다 — 대소문자만 바꿔 가며 두드리면 칸이 갈려서
     * 한도가 그만큼 늘어난다.
     */
    private static String[] keysOf(String email, String clientIp) {
        String normalized = EmailAddress.normalize(email);
        return new String[] {
                "email:" + (normalized == null ? "?" : normalized),
                "ip:" + (clientIp == null ? "?" : clientIp),
        };
    }

    private static final class Counter {
        private final AtomicInteger failures = new AtomicInteger();
        private volatile LocalDateTime lockedUntil;
    }
}
