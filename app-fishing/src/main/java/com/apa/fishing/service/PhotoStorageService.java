package com.apa.fishing.service;

import com.apa.fishing.config.PhotoProperties;
import com.apa.fishing.photo.PhotoTransform;
import com.apa.fishing.photo.UnsupportedImageException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;

/**
 * 조과 인증샷 저장 (기획서 4-3). 리사이즈·EXIF 스트립은 {@link PhotoTransform} 이 하고
 * 여기서는 <b>검증과 파일시스템</b>만 다룬다.
 *
 * <p><b>파일명은 UUID 다.</b> 원본 파일명을 쓰면 경로 조작(`../`)과 한글·공백 인코딩 문제가
 * 한꺼번에 따라오고, 사용자 기기의 파일명이 URL 에 그대로 노출된다.
 *
 * <p>저장 즉시 <b>썸네일(320px)도 함께</b> 굽는다. 도감 그리드는 칸이 40개라 원본 1280px 을
 * 40장 내려받으면 스크롤이 버벅인다. 나중에 굽지 않는 이유는 원본을 다시 읽어야 해서다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PhotoStorageService {

    /** 저장된 사진이 서빙되는 경로. DB {@code photo_url} 에 이 형태로 들어간다. */
    public static final String PUBLIC_PATH = "/fishing/me/photos/";

    private static final String THUMB_SUFFIX = "_thumb";
    private static final String EXTENSION = ".jpg";

    /** JDK ImageIO 가 디코딩할 수 있는 것만 받는다. */
    private static final Set<String> SUPPORTED_TYPES = Set.of("image/jpeg", "image/jpg", "image/png");

    /**
     * 아이폰 기본 포맷이라 기획서 스펙에는 들어 있지만 JDK 에 디코더가 없다. Android 우선 출시라
     * 당장 급하지 않다 — 조용히 500 을 내는 대신 "왜 안 되는지"를 알려주려고 따로 분리해 둔다.
     */
    private static final Set<String> KNOWN_UNSUPPORTED_TYPES = Set.of("image/heic", "image/heif");

    /** 저장된 파일명만 통과시킨다. 경로 조작(`../`)이 load·delete 로 들어오는 걸 여기서 끊는다. */
    private static final Pattern STORED_NAME =
            Pattern.compile("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\\.jpg");

    private final PhotoProperties properties;

    /**
     * @return DB 에 넣을 URL ({@link #PUBLIC_PATH} + 파일명)
     * @throws UnsupportedImageException 형식·크기가 받을 수 없는 것일 때 (호출부가 400 으로 바꾼다)
     */
    public String store(MultipartFile file) {
        validate(file);

        byte[] source = read(file);
        String name = UUID.randomUUID() + EXTENSION;
        Path dir = storageDir();

        byte[] full = PhotoTransform.toJpeg(source, properties.maxEdge(), properties.quality());
        byte[] thumb = PhotoTransform.toJpeg(source, properties.thumbEdge(), properties.quality());

        write(dir.resolve(name), full);
        try {
            write(dir.resolve(thumbName(name)), thumb);
        } catch (UncheckedIOException e) {
            // 썸네일은 있으면 좋은 것이다. 이것 때문에 등록 자체를 실패시키면 사용자는
            // 사진을 다시 고르고 길이를 다시 입력해야 한다. 그리드가 원본을 쓰면 될 뿐이다.
            log.warn("썸네일 저장 실패 (원본은 저장됨): {}", name, e);
        }

        log.debug("조과 사진 저장: {} ({}KB → {}KB)", name, source.length / 1024, full.length / 1024);
        return PUBLIC_PATH + name;
    }

    /** 서빙용 읽기. 파일이 없으면 빈 값이다 — 호출부가 404 로 바꾼다. */
    public Optional<byte[]> load(String fileName, boolean thumb) {
        if (!STORED_NAME.matcher(fileName).matches()) {
            return Optional.empty();
        }
        Path path = storageDir().resolve(thumb ? thumbName(fileName) : fileName);
        // 썸네일 저장이 실패했던 사진은 썸네일만 없다. 원본으로 떨어뜨린다.
        if (thumb && !Files.exists(path)) {
            path = storageDir().resolve(fileName);
        }
        if (!Files.exists(path)) {
            return Optional.empty();
        }
        try {
            return Optional.of(Files.readAllBytes(path));
        } catch (IOException e) {
            log.warn("사진 읽기 실패: {}", fileName, e);
            return Optional.empty();
        }
    }

    /**
     * 기록이 지워지면 사진도 지운다. <b>실패해도 예외를 올리지 않는다</b> — 파일이 남는 건
     * 디스크 낭비지만, 여기서 터지면 사용자는 잘못 등록한 기록을 지우지 못한 채 묶인다.
     * 기획서 3-3 이 삭제를 필수 기능으로 못박은 이유가 그것이다.
     */
    public void delete(String photoUrl) {
        String fileName = fileNameOf(photoUrl);
        if (fileName == null) {
            return;
        }
        deleteQuietly(storageDir().resolve(fileName));
        deleteQuietly(storageDir().resolve(thumbName(fileName)));
    }

    /** {@code /fishing/me/photos/{uuid}.jpg} → {@code {uuid}.jpg}. 우리가 저장한 형태가 아니면 null. */
    public static String fileNameOf(String photoUrl) {
        if (photoUrl == null || !photoUrl.startsWith(PUBLIC_PATH)) {
            return null;
        }
        String name = photoUrl.substring(PUBLIC_PATH.length());
        return STORED_NAME.matcher(name).matches() ? name : null;
    }

    private void validate(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new UnsupportedImageException("사진 파일이 비어 있습니다");
        }
        if (file.getSize() > properties.maxBytes()) {
            throw new UnsupportedImageException(
                    "사진은 %dMB 까지 올릴 수 있습니다".formatted(properties.maxBytes() / 1024 / 1024));
        }

        String type = file.getContentType() == null
                ? "" : file.getContentType().toLowerCase(Locale.ROOT).trim();
        if (KNOWN_UNSUPPORTED_TYPES.contains(type)) {
            throw new UnsupportedImageException("HEIC 사진은 아직 지원하지 않습니다. JPEG 로 저장해 올려주세요");
        }
        if (!SUPPORTED_TYPES.contains(type)) {
            throw new UnsupportedImageException("JPEG 또는 PNG 사진만 올릴 수 있습니다");
        }
    }

    private static byte[] read(MultipartFile file) {
        try {
            return file.getBytes();
        } catch (IOException e) {
            throw new UnsupportedImageException("업로드된 파일을 읽지 못했습니다", e);
        }
    }

    private Path storageDir() {
        Path dir = Path.of(properties.dir());
        try {
            Files.createDirectories(dir);
        } catch (IOException e) {
            throw new UncheckedIOException("사진 저장 디렉터리를 만들지 못했습니다: " + dir, e);
        }
        return dir;
    }

    private static void write(Path path, byte[] bytes) {
        try {
            Files.write(path, bytes);
        } catch (IOException e) {
            throw new UncheckedIOException("사진을 저장하지 못했습니다: " + path, e);
        }
    }

    private static void deleteQuietly(Path path) {
        try {
            Files.deleteIfExists(path);
        } catch (IOException e) {
            log.warn("사진 파일 삭제 실패 (디스크에 남는다): {}", path, e);
        }
    }

    private static String thumbName(String fileName) {
        return fileName.replace(EXTENSION, THUMB_SUFFIX + EXTENSION);
    }
}
