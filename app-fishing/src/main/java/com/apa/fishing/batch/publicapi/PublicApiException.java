package com.apa.fishing.batch.publicapi;

/**
 * 공공데이터포털 호출·파싱 실패. 배치는 포인트 단위로 이걸 잡고 다음 포인트로 넘어간다 —
 * 한 곳이 실패했다고 전체 갱신이 멈추면 안 된다.
 */
public class PublicApiException extends RuntimeException {

    public PublicApiException(String message) {
        super(message);
    }

    public PublicApiException(String message, Throwable cause) {
        super(message, cause);
    }
}
