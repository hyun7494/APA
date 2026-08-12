package com.apa.fishing.batch.khoa;

import com.apa.fishing.batch.publicapi.PublicApiException;

/** 바다낚시지수 호출·파싱 실패. */
public class KhoaApiException extends PublicApiException {

    public KhoaApiException(String message) {
        super(message);
    }

    public KhoaApiException(String message, Throwable cause) {
        super(message, cause);
    }
}
