package com.apa.auth.exception;

/** 이미 쓰이고 있는 값(이메일·소셜 계정)으로 만들려 할 때. */
public class ConflictException extends RuntimeException {

    public ConflictException(String message) {
        super(message);
    }
}
