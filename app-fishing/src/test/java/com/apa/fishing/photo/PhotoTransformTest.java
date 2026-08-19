package com.apa.fishing.photo;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import javax.imageio.ImageIO;
import java.awt.Color;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 저장 파이프라인(기획서 4-3). 사진이 <b>실제로</b> 작아지고, 눕지 않고, EXIF 가 사라지는지 본다.
 * 셋 다 실패해도 등록은 성공하므로 API 응답만 봐서는 드러나지 않는다.
 */
class PhotoTransformTest {

    private static final int MAX_EDGE = 1280;
    private static final float QUALITY = 0.8f;

    @Test
    @DisplayName("긴 변을 1280 으로 줄이고 비율을 유지한다")
    void resizesLongEdge() {
        byte[] jpeg = PhotoTransform.toJpeg(png(4000, 2000), MAX_EDGE, QUALITY);

        BufferedImage result = decode(jpeg);
        assertThat(result.getWidth()).isEqualTo(1280);
        assertThat(result.getHeight()).isEqualTo(640);
    }

    @Test
    @DisplayName("세로로 긴 사진은 높이가 1280 이 된다")
    void resizesPortrait() {
        BufferedImage result = decode(PhotoTransform.toJpeg(png(1000, 3000), MAX_EDGE, QUALITY));

        assertThat(result.getHeight()).isEqualTo(1280);
        assertThat(result.getWidth()).isEqualTo(427);
    }

    @Test
    @DisplayName("원본이 목표보다 작으면 확대하지 않는다")
    void doesNotUpscale() {
        // 확대하면 없던 정보를 만들어 내는 게 아니라 용량만 는다.
        BufferedImage result = decode(PhotoTransform.toJpeg(png(320, 240), MAX_EDGE, QUALITY));

        assertThat(result.getWidth()).isEqualTo(320);
        assertThat(result.getHeight()).isEqualTo(240);
    }

    @Test
    @DisplayName("스마트폰 크기 사진이 실제로 작아진다")
    void actuallyShrinks() {
        // 기획서 4-3 의 전제: 원본 그대로 두면 1장이 3~8MB 다.
        byte[] source = png(4032, 3024);
        byte[] stored = PhotoTransform.toJpeg(source, MAX_EDGE, QUALITY);

        assertThat(stored.length).isLessThan(source.length);
    }

    @Test
    @DisplayName("EXIF 를 통째로 버린다 — GPS 좌표가 저장될 경로가 없다")
    void stripsExif() {
        byte[] withExif = jpegWithOrientation(6, 800, 400);

        byte[] stored = PhotoTransform.toJpeg(withExif, MAX_EDGE, QUALITY);

        // orientation 을 못 읽는다 = APP1 세그먼트 자체가 없다.
        assertThat(ExifOrientation.read(stored)).isEqualTo(ExifOrientation.NORMAL);
        assertThat(indexOfExifMarker(stored)).isEqualTo(-1);
    }

    @Test
    @DisplayName("orientation 6(시계 90도)이면 가로세로가 바뀐다 — 세로 사진이 눕지 않는다")
    void appliesOrientationBeforeStripping() {
        // EXIF 를 버리기 전에 픽셀에 반영하지 않으면, 세로로 찍은 인증샷이 전부 누운 채 저장된다.
        BufferedImage result = decode(
                PhotoTransform.toJpeg(jpegWithOrientation(6, 800, 400), MAX_EDGE, QUALITY));

        assertThat(result.getWidth()).isEqualTo(400);
        assertThat(result.getHeight()).isEqualTo(800);
    }

    @Test
    @DisplayName("orientation 1 은 가로세로를 건드리지 않는다")
    void normalOrientationUnchanged() {
        BufferedImage result = decode(
                PhotoTransform.toJpeg(jpegWithOrientation(1, 800, 400), MAX_EDGE, QUALITY));

        assertThat(result.getWidth()).isEqualTo(800);
        assertThat(result.getHeight()).isEqualTo(400);
    }

    @Test
    @DisplayName("orient(6) 은 좌상단 픽셀을 우상단으로 옮긴다")
    void orientMovesCornerClockwise() {
        // 가로세로만 보면 90도와 270도를 구분하지 못한다 — 실제로 어느 쪽으로 돌았는지 본다.
        BufferedImage source = new BufferedImage(4, 2, BufferedImage.TYPE_INT_RGB);
        source.setRGB(0, 0, Color.RED.getRGB());

        BufferedImage rotated = PhotoTransform.orient(source, 6);

        assertThat(rotated.getWidth()).isEqualTo(2);
        assertThat(rotated.getHeight()).isEqualTo(4);
        assertThat(rotated.getRGB(1, 0)).isEqualTo(Color.RED.getRGB());   // 우상단
    }

    @Test
    @DisplayName("orient(8) 은 좌상단 픽셀을 좌하단으로 옮긴다 (반시계 90도)")
    void orientMovesCornerCounterClockwise() {
        BufferedImage source = new BufferedImage(4, 2, BufferedImage.TYPE_INT_RGB);
        source.setRGB(0, 0, Color.RED.getRGB());

        BufferedImage rotated = PhotoTransform.orient(source, 8);

        assertThat(rotated.getRGB(0, 3)).isEqualTo(Color.RED.getRGB());   // 좌하단
    }

    @Test
    @DisplayName("PNG 의 투명 영역은 흰색이 된다 — 검게 나오지 않는다")
    void flattensTransparency() {
        BufferedImage transparent = new BufferedImage(100, 100, BufferedImage.TYPE_INT_ARGB);
        // 전부 투명. 알파째로 JPEG 에 넘기면 이 영역이 새까맣게 저장된다.

        BufferedImage result = decode(
                PhotoTransform.toJpeg(encode(transparent, "png"), MAX_EDGE, QUALITY));

        Color pixel = new Color(result.getRGB(50, 50));
        assertThat(pixel.getRed()).isGreaterThan(240);
        assertThat(pixel.getBlue()).isGreaterThan(240);
    }

    @Test
    @DisplayName("이미지가 아닌 바이트는 UnsupportedImageException — NPE 로 새지 않는다")
    void rejectsNonImage() {
        // ImageIO.read 는 '못 읽었다'를 예외가 아니라 null 로 알린다. 그대로 흘리면
        // 한참 뒤 NPE 로 터져서 원인이 업로드 파일이라는 걸 못 알아본다.
        assertThatThrownBy(() -> PhotoTransform.toJpeg("이건 사진이 아니다".getBytes(), MAX_EDGE, QUALITY))
                .isInstanceOf(UnsupportedImageException.class);
    }

    // ── 픽스처 ─────────────────────────────────────────────────

    private static byte[] png(int width, int height) {
        BufferedImage image = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        // 단색이면 JPEG 이 극단적으로 잘 압축돼 크기 비교가 의미를 잃는다. 무늬를 넣는다.
        for (int y = 0; y < height; y += 2) {
            for (int x = 0; x < width; x += 2) {
                image.setRGB(x, y, (x * 7 + y * 13) & 0xFFFFFF);
            }
        }
        return encode(image, "png");
    }

    /** ImageIO 로 만든 정상 JPEG 의 SOI 바로 뒤에 APP1(Exif) 세그먼트를 끼워 넣는다. */
    private static byte[] jpegWithOrientation(int orientation, int width, int height) {
        byte[] jpeg = encode(decode(png(width, height)), "jpeg");
        byte[] app1 = exifApp1(orientation);

        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.write(jpeg[0]);   // 0xFF
        out.write(jpeg[1]);   // 0xD8 SOI
        out.writeBytes(app1);
        out.writeBytes(java.util.Arrays.copyOfRange(jpeg, 2, jpeg.length));
        return out.toByteArray();
    }

    /** 리틀엔디언 TIFF 에 Orientation 태그 하나만 담은 APP1 세그먼트. */
    private static byte[] exifApp1(int orientation) {
        ByteArrayOutputStream tiff = new ByteArrayOutputStream();
        tiff.writeBytes(new byte[]{'I', 'I'});
        writeLe16(tiff, 42);
        writeLe32(tiff, 8);
        writeLe16(tiff, 1);          // 엔트리 수
        writeLe16(tiff, 0x0112);     // Orientation
        writeLe16(tiff, 3);          // SHORT
        writeLe32(tiff, 1);
        writeLe16(tiff, orientation);
        writeLe16(tiff, 0);
        writeLe32(tiff, 0);          // 다음 IFD 없음

        byte[] body = tiff.toByteArray();
        int length = 2 + 6 + body.length;

        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.write(0xFF);
        out.write(0xE1);
        out.write((length >> 8) & 0xFF);   // 세그먼트 길이는 빅엔디언
        out.write(length & 0xFF);
        out.writeBytes(new byte[]{'E', 'x', 'i', 'f', 0, 0});
        out.writeBytes(body);
        return out.toByteArray();
    }

    /** 저장된 JPEG 어디에도 "Exif\0\0" 이 남지 않았는지 확인한다. */
    private static int indexOfExifMarker(byte[] data) {
        byte[] marker = {'E', 'x', 'i', 'f', 0, 0};
        outer:
        for (int i = 0; i + marker.length <= data.length; i++) {
            for (int j = 0; j < marker.length; j++) {
                if (data[i + j] != marker[j]) {
                    continue outer;
                }
            }
            return i;
        }
        return -1;
    }

    private static void writeLe16(ByteArrayOutputStream out, int value) {
        out.write(value & 0xFF);
        out.write((value >> 8) & 0xFF);
    }

    private static void writeLe32(ByteArrayOutputStream out, int value) {
        writeLe16(out, value & 0xFFFF);
        writeLe16(out, (value >> 16) & 0xFFFF);
    }

    private static byte[] encode(BufferedImage image, String format) {
        try {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            ImageIO.write(image, format, out);
            return out.toByteArray();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    private static BufferedImage decode(byte[] bytes) {
        try {
            return ImageIO.read(new ByteArrayInputStream(bytes));
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}
