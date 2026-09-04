package com.apa.fishing.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

/**
 * 탈퇴한 사람의 글에 남길 이름 — {@code 탈퇴한 사용자 a3f9}.
 *
 * <p>★ <b>{@code user_id} 를 그대로 쓰지 않는다.</b> 내부 id 를 화면에 박으면 게시판 전체에서
 * 남의 계정 번호를 주워 갈 수 있고, 순번이라 몇 번째 가입자인지까지 드러난다.
 * 대신 <b>서버만 아는 값을 섞어 해시</b>해서 짧게 자른다.
 *
 * <p>같은 사람의 글은 같은 꼬리표를 달아 <b>글타래가 이어져 읽힌다</b>. 그 대신 게시판
 * 전체에서 "이 글들이 한 사람" 이라는 것도 보인다 — 번호를 붙이기로 한 이상 따라오는 값이다.
 * 그것까지 끊으려면 꼬리표를 아예 없애야 한다(레딧의 {@code [deleted]} 방식).
 *
 * <p>네 자리라 사람이 많아지면 겹친다. 겹쳐도 <b>탈퇴자끼리 섞일 뿐</b>이라 문제가 없고,
 * 오히려 익명성이 조금 는다.
 */
@Component
public class WithdrawnName {

    private static final String PREFIX = "탈퇴한 사용자 ";

    /** 꼬리표 길이(hex 문자 수). 늘리면 이미 마스킹한 글과 모양이 달라지므로 바꾸지 말 것. */
    private static final int LENGTH = 4;

    private final byte[] secret;

    /** 되짚기를 실제로 막는 최소 길이. 짧으면 비밀값 자체를 전수 대입할 수 있다. */
    private static final int MIN_SECRET_LENGTH = 16;

    /**
     * @param secret 해시에 섞는 서버 비밀값.
     *
     * <p>★ <b>기본값이 없다.</b> 예전엔 {@code apa-local-dev} 가 박혀 있었는데, 공개
     * 저장소라 그 값을 아는 누구나 {@code SHA256(비밀값 + id)} 를 1 부터 돌려
     * <b>꼬리표를 내부 user_id 로 되짚을 수 있었다.</b> user_id 가 작은 정수라
     * 전수 대입이 순식간이다 — 실제로 {@code 탈퇴한 사용자 69b6} 에서 4번을 복원했다.
     *
     * <p>더 나쁜 건 이 값이 <b>어디에서도 주입되지 않아</b> 늘 그 기본값으로 돌았다는
     * 것이다. 익명화를 하고 있다고 믿는 채로 안 하고 있었다.
     *
     * <p>{@code JWT_SECRET} 과 같은 규칙을 쓴다 — 없으면 부팅이 실패하는 편이 낫다.
     */
    public WithdrawnName(@Value("${fishing.withdrawn.secret}") String secret) {
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException(
                    "WITHDRAWN_SECRET 이 필요하다 — 없으면 탈퇴자 꼬리표를 user_id 로 되짚을 수 있다");
        }
        if (secret.length() < MIN_SECRET_LENGTH) {
            throw new IllegalStateException(
                    "WITHDRAWN_SECRET 이 너무 짧다 (%d자 이상): 지금 %d자"
                            .formatted(MIN_SECRET_LENGTH, secret.length()));
        }
        this.secret = secret.getBytes(StandardCharsets.UTF_8);
    }

    public String of(Long userId) {
        if (userId == null) {
            // 시드 글처럼 주인이 없는 글. 꼬리표를 붙일 근거가 없다.
            return PREFIX.trim();
        }
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            digest.update(secret);
            digest.update(String.valueOf(userId).getBytes(StandardCharsets.UTF_8));
            String hex = HexFormat.of().formatHex(digest.digest());
            return PREFIX + hex.substring(0, LENGTH);
        } catch (NoSuchAlgorithmException e) {
            // SHA-256 은 표준 JDK 에 반드시 있다. 여기 오면 실행 환경이 깨진 것이다.
            throw new IllegalStateException("SHA-256 을 쓸 수 없다", e);
        }
    }
}
