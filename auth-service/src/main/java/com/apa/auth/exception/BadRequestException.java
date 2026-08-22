package com.apa.auth.exception;

/** 입력이 형식에 맞지 않을 때. 사용자가 고칠 수 있는 문제이므로 메시지를 그대로 보여 준다. */
public class BadRequestException extends RuntimeException {

    public BadRequestException(String message) {
        super(message);
    }
}
