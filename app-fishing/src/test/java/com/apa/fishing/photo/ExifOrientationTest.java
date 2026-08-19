package com.apa.fishing.photo;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.io.ByteArrayOutputStream;
import java.util.Arrays;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * EXIF Orientation 파싱. 이 값이 틀리면 세로로 찍은 인증샷이 도감 칸에 누워서 들어가는데,
 * <b>저장은 성공하므로 아무 에러도 안 난다.</b> 사진을 눈으로 봐야만 드러나는 종류의 버그라
 * 바이트를 직접 조립해서 검증한다.
 */
class ExifOrientationTest {

    @ParameterizedTest(name = "orientation {0} 을 그대로 읽는다")
    @ValueSource(ints = {1, 2, 3, 4, 5, 6, 7, 8})
    void readsEveryOrientation(int orientation) {
        assertThat(ExifOrientation.read(jpegWithOrientation(orientation, true)))
                .isEqualTo(orientation);
    }

    @Test
    @DisplayName("빅엔디언(MM) TIFF 도 읽는다")
    void bigEndian() {
        // 대부분의 기기가 리틀엔디언(II)이라 빅엔디언은 실물을 보기 어렵다.
        // 바이트 순서를 뒤집어 읽으면 orientation 6 이 0x0600 = 1536 으로 나와 조용히 1 로 떨어진다.
        assertThat(ExifOrientation.read(jpegWithOrientation(6, false))).isEqualTo(6);
    }

    @Test
    @DisplayName("EXIF 가 없는 JPEG 은 1")
    void noExif() {
        byte[] jpeg = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xDA, 0, 2};
        assertThat(ExifOrientation.read(jpeg)).isEqualTo(ExifOrientation.NORMAL);
    }

    @Test
    @DisplayName("PNG 처럼 JPEG 이 아닌 바이트는 1 (예외가 아니다)")
    void notJpeg() {
        byte[] png = {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A};
        assertThat(ExifOrientation.read(png)).isEqualTo(ExifOrientation.NORMAL);
    }

    @Test
    @DisplayName("잘린 파일도 예외 없이 1")
    void truncated() {
        byte[] full = jpegWithOrientation(6, true);
        // 업로드가 중간에 끊기면 실제로 이런 바이트가 들어온다. 인덱스 밖을 읽고 터지면
        // 사용자에게는 500 이 나가는데, 원인이 사진이라는 걸 로그만 보고는 알 수 없다.
        for (int cut = 1; cut < full.length; cut++) {
            assertThat(ExifOrientation.read(Arrays.copyOf(full, cut)))
                    .isIn(ExifOrientation.NORMAL, 6);
        }
    }

    @Test
    @DisplayName("범위를 벗어난 값(0, 9)은 1 로 떨어뜨린다")
    void outOfRange() {
        assertThat(ExifOrientation.read(jpegWithOrientation(0, true))).isEqualTo(1);
        assertThat(ExifOrientation.read(jpegWithOrientation(9, true))).isEqualTo(1);
    }

    @Test
    @DisplayName("null·빈 배열도 1")
    void empty() {
        assertThat(ExifOrientation.read(null)).isEqualTo(ExifOrientation.NORMAL);
        assertThat(ExifOrientation.read(new byte[0])).isEqualTo(ExifOrientation.NORMAL);
    }

    @Test
    @DisplayName("transforms() 는 1 만 거짓")
    void transforms() {
        assertThat(ExifOrientation.transforms(1)).isFalse();
        assertThat(ExifOrientation.transforms(6)).isTrue();
        assertThat(ExifOrientation.transforms(9)).isFalse();
    }

    // ── 테스트용 JPEG 조립 ──────────────────────────────────────
    //
    // 실제 사진 파일을 리소스로 넣지 않는 이유: orientation 8 개 × 엔디언 2 종의 실물을 구하기
    // 어렵고, 바이너리 픽스처는 무엇을 검증하는지가 파일 안에 숨는다. 여기서는 구조가 코드로 보인다.

    /** SOI + APP1(Exif/TIFF/IFD0 에 Orientation 1개) + SOS. 픽셀 데이터는 없다 — 파서가 안 본다. */
    private static byte[] jpegWithOrientation(int orientation, boolean littleEndian) {
        ByteArrayOutputStream tiff = new ByteArrayOutputStream();
        write16(tiff, littleEndian ? 0x4949 : 0x4D4D, false);   // 바이트 순서 표시는 항상 빅엔디언으로 읽힌다
        write16(tiff, 42, littleEndian);                        // TIFF 매직
        write32(tiff, 8, littleEndian);                         // IFD0 오프셋 (TIFF 헤더 기준)
        write16(tiff, 1, littleEndian);                         // 엔트리 1개
        write16(tiff, 0x0112, littleEndian);                    // 태그 = Orientation
        write16(tiff, 3, littleEndian);                         // 타입 = SHORT
        write32(tiff, 1, littleEndian);                         // 개수
        write16(tiff, orientation, littleEndian);               // 값 (4바이트 필드의 앞 2바이트)
        write16(tiff, 0, littleEndian);                         // 남는 2바이트
        write32(tiff, 0, littleEndian);                         // 다음 IFD 없음

        byte[] exifBody = tiff.toByteArray();
        int app1Length = 2 + 6 + exifBody.length;               // 길이 필드 자신 + "Exif\0\0" + TIFF

        ByteArrayOutputStream jpeg = new ByteArrayOutputStream();
        jpeg.write(0xFF);
        jpeg.write(0xD8);                                       // SOI
        jpeg.write(0xFF);
        jpeg.write(0xE1);                                       // APP1
        write16(jpeg, app1Length, false);                       // 세그먼트 길이는 항상 빅엔디언
        jpeg.writeBytes(new byte[]{'E', 'x', 'i', 'f', 0, 0});
        jpeg.writeBytes(exifBody);
        jpeg.write(0xFF);
        jpeg.write(0xDA);                                       // SOS
        write16(jpeg, 2, false);
        return jpeg.toByteArray();
    }

    private static void write16(ByteArrayOutputStream out, int value, boolean littleEndian) {
        if (littleEndian) {
            out.write(value & 0xFF);
            out.write((value >> 8) & 0xFF);
        } else {
            out.write((value >> 8) & 0xFF);
            out.write(value & 0xFF);
        }
    }

    private static void write32(ByteArrayOutputStream out, int value, boolean littleEndian) {
        if (littleEndian) {
            out.write(value & 0xFF);
            out.write((value >> 8) & 0xFF);
            out.write((value >> 16) & 0xFF);
            out.write((value >> 24) & 0xFF);
        } else {
            out.write((value >> 24) & 0xFF);
            out.write((value >> 16) & 0xFF);
            out.write((value >> 8) & 0xFF);
            out.write(value & 0xFF);
        }
    }
}
