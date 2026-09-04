package com.apa.fishing.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 평평하게 쌓여 있던 사진을 <b>범위별 폴더로 옮긴다</b> (일회성).
 *
 * <p>{@link PhotoScope} 가 생기기 전에는 조과 인증샷과 게시글 사진이 저장 루트에 섞여
 * 있었다. 폴더를 가르는 것으로 접근 제어를 고쳤으므로, 옮기지 않으면 <b>이미 올라간
 * 사진이 전부 404 가 된다.</b>
 *
 * <p>어느 폴더로 갈지는 <b>DB 가 안다</b> — {@code photo_url} 의 앞부분이 곧 범위다.
 * 파일 이름만 봐서는 알 수 없어서 여기서 질의한다.
 *
 * <p>★ <b>어느 표에도 없는 파일은 비공개(CATCH)로 보낸다.</b> 반대로 하면 주인을 모르는
 * 파일이 공개 폴더로 가서 누구나 열 수 있게 된다 — 모를 때 안전한 쪽은 감추는 쪽이다.
 *
 * <p>여러 번 돌아도 안전하다. 옮길 것이 없으면 아무 일도 안 하고, 이미 목적지에 있으면
 * 건너뛴다. 마이그레이션이 끝난 배포에서는 로그 한 줄도 안 남는다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class PhotoLayoutMigration {

    private static final String THUMB_SUFFIX = "_thumb";
    private static final String EXTENSION = ".jpg";

    private final PhotoStorageService photoStorage;
    private final JdbcTemplate jdbc;

    /**
     * 부팅 직후 한 번. 지수 배치와 달리 <b>빨리 끝나야 하므로 같은 스레드에서</b> 돈다 —
     * 이게 끝나기 전에 사진 요청이 오면 잠깐 404 가 나기 때문이다.
     */
    @EventListener(ApplicationReadyEvent.class)
    public void migrate() {
        Path root = photoStorage.rootDir();
        if (!Files.isDirectory(root)) {
            return;
        }

        List<Path> stray = strayFiles(root);
        if (stray.isEmpty()) {
            return;
        }

        Map<String, PhotoScope> scopeByName = scopeByFileName();
        int moved = 0;
        for (Path file : stray) {
            String name = file.getFileName().toString();
            // 썸네일은 원본과 같은 곳으로 간다.
            String originName = name.replace(THUMB_SUFFIX + EXTENSION, EXTENSION);
            PhotoScope scope = scopeByName.getOrDefault(originName, PhotoScope.CATCH);

            if (move(file, photoStorage.storageDir(scope).resolve(name))) {
                moved++;
            }
        }
        log.info("사진 폴더 정리: {}개 중 {}개를 범위별 폴더로 옮겼다", stray.size(), moved);
    }

    /** 저장 루트에 바로 놓인 jpg (하위 폴더는 이미 정리된 것이다). */
    private List<Path> strayFiles(Path root) {
        try (var entries = Files.list(root)) {
            return entries
                    .filter(Files::isRegularFile)
                    .filter(p -> p.getFileName().toString().endsWith(EXTENSION))
                    .toList();
        } catch (IOException e) {
            log.warn("사진 폴더를 읽지 못해 정리를 건너뛴다: {}", root, e);
            return List.of();
        }
    }

    /**
     * 파일 이름 → 범위. {@code photo_url} 앞부분이 곧 범위다.
     *
     * <p>⚠️ 이 클래스는 마이그레이션이라 <b>일부러 JdbcTemplate 을 쓴다.</b> 엔티티로 읽으면
     * 나중에 매핑이 바뀔 때 옛 데이터를 못 읽어서, 정리 코드가 스키마 변경에 발이 묶인다.
     */
    private Map<String, PhotoScope> scopeByFileName() {
        Map<String, PhotoScope> map = new HashMap<>();
        collect(map, "SELECT photo_url FROM fishing_catch_photos");
        collect(map, "SELECT photo_url FROM fishing_posts WHERE photo_url IS NOT NULL");
        return map;
    }

    private void collect(Map<String, PhotoScope> map, String sql) {
        for (String url : jdbc.queryForList(sql, String.class)) {
            PhotoScope scope = PhotoScope.of(url);
            String name = PhotoStorageService.fileNameOf(url);
            if (scope != null && name != null) {
                map.put(name, scope);
            }
        }
    }

    private boolean move(Path from, Path to) {
        try {
            if (Files.exists(to)) {
                Files.delete(from);   // 이미 옮겨진 것. 사본을 남기지 않는다.
                return false;
            }
            Files.move(from, to, StandardCopyOption.ATOMIC_MOVE);
            return true;
        } catch (IOException e) {
            // 한 장 때문에 부팅을 막지 않는다. 그 사진만 404 가 되고 나머지는 산다.
            log.warn("사진을 옮기지 못했다 (그 사진은 안 보인다): {}", from, e);
            return false;
        }
    }
}
