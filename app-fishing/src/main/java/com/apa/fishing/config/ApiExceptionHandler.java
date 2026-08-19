package com.apa.fishing.config;

import com.apa.fishing.photo.UnsupportedImageException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

/**
 * 업로드 관련 예외를 <b>사용자 잘못(4xx)으로 못박는다.</b> 그냥 두면 둘 다 500 으로 나가는데,
 * 그러면 사진 한 장 때문에 앱이 "서버 오류"를 띄우고 우리는 알림을 보고 서버를 뒤지게 된다.
 *
 * <p>{@link ProblemDetail} 을 쓰는 이유는 스프링 기본 에러 본문과 모양을 맞추기 위해서다 —
 * 프론트가 에러 표시를 붙일 때 경로마다 다른 형태를 처리하지 않아도 된다.
 */
@Slf4j
@RestControllerAdvice
public class ApiExceptionHandler {

    @ExceptionHandler(UnsupportedImageException.class)
    public ProblemDetail unsupportedImage(UnsupportedImageException e) {
        log.debug("사진 업로드 거절: {}", e.getMessage());
        return ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, e.getMessage());
    }

    /**
     * {@code spring.servlet.multipart.max-file-size} 를 넘으면 서블릿 컨테이너가 파일을 읽기도 전에
     * 던진다 — {@code PhotoStorageService} 의 크기 검사까지 오지 못하므로 여기서 같은 안내를 낸다.
     */
    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ProblemDetail tooLarge(MaxUploadSizeExceededException e) {
        log.debug("사진 업로드 크기 초과", e);
        return ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, "사진 용량이 너무 큽니다");
    }
}
