package com.apa.fishing.dto;

import com.apa.fishing.domain.CatchRecord;
import com.apa.fishing.domain.Habitat;
import com.apa.fishing.domain.Rarity;
import com.apa.fishing.domain.Species;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 도감 칸 조립 규칙.
 *
 * <p>이 규칙들은 프론트 {@code MockFishingRepository._entryFor} 와 <b>같아야 한다.</b>
 * 다르면 {@code USE_MOCK} 을 끄는 순간 도감 표지와 최고 기록이 바뀌어, 서버 문제인지
 * 화면 문제인지 가리기 어려운 종류의 어긋남이 된다.
 */
class CollectionEntryResponseTest {

    private final Species gamseongdom = species(1L, "감성돔", Rarity.COMMON);

    @Test
    @DisplayName("기록이 없으면 잠긴 칸 — 어종 정보는 그대로 나간다")
    void lockedKeepsSpecies() {
        CollectionEntryResponse entry = CollectionEntryResponse.of(gamseongdom, List.of());

        assertThat(entry.catchCount()).isZero();
        assertThat(entry.bestLengthCm()).isNull();
        assertThat(entry.coverPhotoUrl()).isNull();
        // 잠긴 칸이라도 이름은 가리지 않는다 — 뭘 잡아야 할지 알아야 다음 출조 동기가 생긴다.
        assertThat(entry.species().name()).isEqualTo("감성돔");
    }

    @Test
    @DisplayName("최고 기록과 표지는 가장 큰 개체의 것이다 — 최신이 아니다")
    void bestIsLongestNotLatest() {
        // 어제 잡은 20cm 가 작년의 45cm 를 밀어내면 칸이 초라해진다.
        var small = catchOf(20.0, "/fishing/me/photos/small.jpg", LocalDateTime.of(2026, 8, 16, 9, 0));
        var big = catchOf(45.0, "/fishing/me/photos/big.jpg", LocalDateTime.of(2025, 3, 2, 9, 0));

        CollectionEntryResponse entry = CollectionEntryResponse.of(gamseongdom, List.of(small, big));

        assertThat(entry.bestLengthCm()).isEqualTo(45.0);
        assertThat(entry.coverPhotoUrl()).isEqualTo("/fishing/me/photos/big.jpg");
        assertThat(entry.catchCount()).isEqualTo(2);
    }

    @Test
    @DisplayName("firstCaughtAt 은 가장 이른 기록 — 이 종을 처음 만난 날이다")
    void firstCaughtAtIsEarliest() {
        var later = catchOf(20.0, null, LocalDateTime.of(2026, 8, 16, 9, 0));
        var earlier = catchOf(45.0, null, LocalDateTime.of(2025, 3, 2, 9, 0));

        CollectionEntryResponse entry = CollectionEntryResponse.of(gamseongdom, List.of(later, earlier));

        assertThat(entry.firstCaughtAt()).isEqualTo(LocalDateTime.of(2025, 3, 2, 9, 0));
    }

    @Test
    @DisplayName("사진 없이 등록된 기록은 표지가 null — 빈 문자열을 URL 로 내보내지 않는다")
    void blankPhotoIsNotACover() {
        // 프론트가 빈 문자열을 URL 로 알고 깨진 이미지를 그린다.
        // (피커 연동 전까지는 사진 없이 등록되는 경로가 살아 있다)
        var noPhoto = catchOf(30.0, "", LocalDateTime.now());

        assertThat(CollectionEntryResponse.of(gamseongdom, List.of(noPhoto)).coverPhotoUrl()).isNull();
    }

    @Test
    @DisplayName("★ 길이 없는 기록이 섞여도 최고 기록을 고른다 (V11) — 도감이 NPE 로 죽지 않는다")
    void missingLengthIsSmallest() {
        // 길이는 선택이라 null 이 섞인다. 어종 36칸이 전부 이 조립을 타므로
        // 여기서 터지면 도감 화면 전체가 안 뜬다.
        var unknown = catchOf(null, "/fishing/me/photos/unknown.jpg", LocalDateTime.of(2026, 8, 1, 9, 0));
        var measured = catchOf(BigDecimal.valueOf(31.5), "/fishing/me/photos/a.jpg", LocalDateTime.of(2026, 8, 2, 9, 0));

        CollectionEntryResponse entry = CollectionEntryResponse.of(gamseongdom, List.of(unknown, measured));

        assertThat(entry.bestLengthCm()).isEqualTo(31.5);
        assertThat(entry.catchCount()).isEqualTo(2);
    }

    @Test
    @DisplayName("★ 길이가 하나도 없으면 최고 기록은 null — 0.0 으로 떨어뜨리지 않는다")
    void allMissingLengthLeavesBestNull() {
        // 0.0 을 내보내면 화면이 "0.0cm 를 쟀다"로 읽는다. 안 잰 것과 0은 다르다.
        var unknown = catchOf(null, "/fishing/me/photos/unknown.jpg", LocalDateTime.now());

        CollectionEntryResponse entry = CollectionEntryResponse.of(gamseongdom, List.of(unknown));

        assertThat(entry.bestLengthCm()).isNull();
        assertThat(entry.coverPhotoUrl()).isEqualTo("/fishing/me/photos/unknown.jpg");
    }

    @Test
    @DisplayName("★ 가장 큰 개체에 사진이 없으면 사진 있는 것 중 가장 큰 것이 표지다")
    void coverFallsBackToLargestWithPhoto() {
        // 최고 기록과 표지가 갈릴 수 있다 — 칸을 비워 두는 것보다 낫다.
        var biggestNoPhoto = catchOf(45.0, null, LocalDateTime.of(2026, 8, 2, 9, 0));
        var midWithPhoto = catchOf(38.0, "/fishing/me/photos/mid.jpg", LocalDateTime.of(2026, 8, 3, 9, 0));
        var smallWithPhoto = catchOf(20.0, "/fishing/me/photos/small.jpg", LocalDateTime.of(2026, 8, 4, 9, 0));

        CollectionEntryResponse entry = CollectionEntryResponse.of(
                gamseongdom, List.of(biggestNoPhoto, midWithPhoto, smallWithPhoto));

        assertThat(entry.bestLengthCm()).isEqualTo(45.0);
        assertThat(entry.coverPhotoUrl()).isEqualTo("/fishing/me/photos/mid.jpg");
    }

    @Test
    @DisplayName("한 건만 있어도 획득이다 — catchCount 1")
    void singleCatchOwnsTheTile() {
        var one = catchOf(31.5, "/fishing/me/photos/a.jpg", LocalDateTime.now());

        assertThat(CollectionEntryResponse.of(gamseongdom, List.of(one)).catchCount()).isEqualTo(1);
    }

    // ── 픽스처 ─────────────────────────────────────────────────
    //
    // Species 는 시드로만 만들어지는 읽기 전용 엔티티라 생성자가 없다.
    // 테스트를 위해 세터를 열면 운영 코드에서도 어종 마스터가 바뀔 수 있게 되므로 리플렉션을 쓴다.

    private static Species species(Long id, String name, Rarity rarity) {
        Species species = newSpecies();
        ReflectionTestUtils.setField(species, "id", id);
        ReflectionTestUtils.setField(species, "name", name);
        ReflectionTestUtils.setField(species, "habitat", Habitat.SEA);
        ReflectionTestUtils.setField(species, "rarity", rarity);
        ReflectionTestUtils.setField(species, "displayOrder", 1);
        ReflectionTestUtils.setField(species, "active", true);
        return species;
    }

    /** JPA 용 protected 기본 생성자. 테스트가 다른 패키지라 직접은 못 부른다. */
    private static Species newSpecies() {
        try {
            var constructor = Species.class.getDeclaredConstructor();
            constructor.setAccessible(true);
            return constructor.newInstance();
        } catch (ReflectiveOperationException e) {
            throw new IllegalStateException("Species 기본 생성자를 부를 수 없다", e);
        }
    }

    private CatchRecord catchOf(double lengthCm, String photoUrl, LocalDateTime caughtAt) {
        return catchOf(BigDecimal.valueOf(lengthCm), photoUrl, caughtAt);
    }

    /** 길이는 선택이라 null 도 받는다 (V11). */
    private CatchRecord catchOf(BigDecimal lengthCm, String photoUrl, LocalDateTime caughtAt) {
        CatchRecord record = CatchRecord.create(7L, gamseongdom, lengthCm, caughtAt);
        record.replacePhotos(photoUrl == null ? List.of() : List.of(photoUrl));
        return record;
    }
}
