package com.apa.fishing.photo;

/**
 * 업로드된 바이트를 이미지로 다룰 수 없을 때. <b>서버 잘못이 아니라 요청 잘못이므로</b>
 * 호출부가 400 으로 바꿔 내보낸다 — 500 으로 나가면 사용자는 "앱이 고장났다"로 읽고,
 * 우리는 알림을 보고 서버를 뒤지게 된다.
 */
public class UnsupportedImageException extends RuntimeException {

    public UnsupportedImageException(String message) {
        super(message);
    }

    public UnsupportedImageException(String message, Throwable cause) {
        super(message, cause);
    }
}
