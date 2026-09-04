package com.apa.auth.exception;

/** 로그인 시도가 한도를 넘었다. 429 로 나간다. */
public class TooManyAttemptsException extends RuntimeException {

    public TooManyAttemptsException(String message) {
        super(message);
    }
}
