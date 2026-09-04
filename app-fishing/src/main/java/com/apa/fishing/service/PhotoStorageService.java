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

    /**
     * 저장된 사진이 서빙되는 경로. DB {@code photo_url} 에 이 형태로 들어간다.
     *
     * <p>경로와 폴더는 {@link PhotoScope} 가 함께 들고 있다 — 둘이 갈리면 접근 정책이
     * 새는 자리가 생긴다 (그 열거의 주석 참고).
     */
    public static final String PUBLIC_PATH = PhotoScope.CATCH.urlPrefix();

    /** 게시글 사진. <b>누구나 열람</b>이다 — 글 자체가 공개고 글쓴이가 붙인 것이다. */
    public static final String BOARD_PATH = PhotoScope.BOARD.urlPrefix();

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
        return store(file, PhotoScope.CATCH);
    }

    private String store(MultipartFile file, PhotoScope scope) {
        validate(file);

        byte[] source = read(file);
        String name = UUID.randomUUID() + EXTENSION;
        Path dir = storageDir(scope);

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

        log.debug("사진 저장: {}/{} ({}KB → {}KB)",
                scope.directory(), name, source.length / 1024, full.length / 1024);
        return scope.urlPrefix() + name;
    }

    /**
     * 게시글 사진 저장.
     *
     * <p>★ <b>예전에는 {@link #store} 를 그대로 부르고 URL 앞부분만 바꿨다.</b> 그래서 두
     * 종류가 한 폴더에 섞였고, 인증 없는 게시판 경로로 <b>남의 조과 인증샷을 그대로 받아
     * 갈 수 있었다.</b> 이제 폴더부터 다르다.
     *
     * @return DB 에 넣을 URL ({@link #BOARD_PATH} + 파일명)
     */
    public String storeForBoard(MultipartFile file) {
        return store(file, PhotoScope.BOARD);
    }

    /**
     * 서빙용 읽기. 파일이 없으면 빈 값이다 — 호출부가 404 로 바꾼다.
     *
     * <p>★ <b>범위를 반드시 받는다.</b> 이 인자가 없던 시절에는 파일명만 보고 읽어서,
     * 게시판(인증 없음) 경로로 조과 인증샷(본인만)을 꺼낼 수 있었다. 이제 요청한 범위의
     * 폴더 밖은 <b>존재 자체를 모른다.</b>
     */
    public Optional<byte[]> load(PhotoScope scope, String fileName, boolean thumb) {
        if (!STORED_NAME.matcher(fileName).matches()) {
            return Optional.empty();
        }
        Path dir = storageDir(scope);
        Path path = dir.resolve(thumb ? thumbName(fileName) : fileName);
        // 썸네일 저장이 실패했던 사진은 썸네일만 없다. 원본으로 떨어뜨린다.
        if (thumb && !Files.exists(path)) {
            path = dir.resolve(fileName);
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
        PhotoScope scope = PhotoScope.of(photoUrl);
        String fileName = fileNameOf(photoUrl);
        if (scope == null || fileName == null) {
            return;
        }
        Path dir = storageDir(scope);
        deleteQuietly(dir.resolve(fileName));
        deleteQuietly(dir.resolve(thumbName(fileName)));
    }

    /**
     * {@code /fishing/me/photos/{uuid}.jpg} → {@code {uuid}.jpg}.
     * 우리가 저장한 형태가 아니면 null.
     *
     * <p>⚠️ <b>예전에는 조과 경로만 벗겨낼 줄 알았다.</b> 그래서 게시글 사진을 지우라고
     * 하면 null 이 나와 {@link #delete} 가 조용히 되돌아갔고, <b>지운 글의 사진이 디스크에
     * 남아 공개 URL 로 계속 열렸다.</b> 이제 두 경로를 다 안다.
     */
    public static String fileNameOf(String photoUrl) {
        PhotoScope scope = PhotoScope.of(photoUrl);
        if (scope == null) {
            return null;
        }
        String name = photoUrl.substring(scope.urlPrefix().length());
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

    /** 저장 루트. 마이그레이션이 옛 평평한 배치를 찾을 때도 쓴다. */
    Path rootDir() {
        return Path.of(properties.dir());
    }

    Path storageDir(PhotoScope scope) {
        Path dir = rootDir().resolve(scope.directory());
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
