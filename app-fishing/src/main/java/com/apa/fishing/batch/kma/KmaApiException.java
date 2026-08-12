package com.apa.fishing.batch.kma;

/**
 * 단기예보 호출·파싱 실패. 배치는 포인트 단위로 이걸 잡고 다음 포인트로 넘어간다.
 */
public class KmaApiException extends RuntimeException {

    public KmaApiException(String message) {
        super(message);
    }

    public KmaApiException(String message, Throwable cause) {
        super(message, cause);
    }
}
