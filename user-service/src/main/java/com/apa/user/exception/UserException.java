package com.apa.user.exception;

public class UserException extends RuntimeException {

    private final ErrorCode errorCode;

    public UserException(ErrorCode errorCode) {
        super(errorCode.getMessage());
        this.errorCode = errorCode;
    }

    public ErrorCode getErrorCode() {
        return errorCode;
    }

    public enum ErrorCode {
        USER_NOT_FOUND("사용자를 찾을 수 없습니다."),
        USERNAME_ALREADY_EXISTS("이미 사용 중인 username입니다."),
        EMAIL_ALREADY_EXISTS("이미 사용 중인 email입니다.");

        private final String message;

        ErrorCode(String message) {
            this.message = message;
        }

        public String getMessage() {
            return message;
        }
    }
}
