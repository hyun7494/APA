package com.apa.fishing.batch.kma;

import com.apa.fishing.batch.publicapi.PublicApiException;

/** 단기예보 호출·파싱 실패. */
public class KmaApiException extends PublicApiException {

    public KmaApiException(String message) {
        super(message);
    }

    public KmaApiException(String message, Throwable cause) {
        super(message, cause);
    }
}
