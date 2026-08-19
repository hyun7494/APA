package com.apa.fishing.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 조과 인증샷 저장 설정. {@code application.yml} 의 {@code fishing.photo.*} 를 받는다 (기획서 4-3).
 *
 * <p>기본값은 <b>로컬 볼륨</b>이다. 기획서는 "board-lib 에 이미지 인프라가 있으면 재사용, 없으면
 * 로컬 볼륨 또는 S3 호환 스토리지 중 택1"이라고 했는데, board-lib 는 결국 만들지 않기로 했고
 * (V3 주석) 게시판에도 이미지 업로드가 아직 없다. 재사용할 인프라가 없으므로 로컬로 간다 —
 * S3 로 옮길 때 갈아 끼울 지점은 {@code PhotoStorageService} 하나다.
 */
@ConfigurationProperties(prefix = "fishing.photo")
public record PhotoProperties(
        String dir,
        long maxBytes,
        int maxEdge,
        int thumbEdge,
        float quality
) {

    public PhotoProperties {
        dir = (dir == null || dir.isBlank()) ? "data/photos" : dir.trim();
        maxBytes = maxBytes > 0 ? maxBytes : 15L * 1024 * 1024;   // 기획서 4-3: 요청당 1장, 최대 15MB
        maxEdge = maxEdge > 0 ? maxEdge : 1280;                   // 긴 변 1280px
        thumbEdge = thumbEdge > 0 ? thumbEdge : 320;              // 도감 그리드용 썸네일
        quality = quality > 0 ? quality : 0.8f;                   // JPEG 품질 80
    }
}
