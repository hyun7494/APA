package com.apa.fishing.photo;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageOutputStream;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.geom.AffineTransform;
import java.awt.image.AffineTransformOp;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Iterator;

/**
 * 업로드 사진 → 저장용 JPEG. 파일시스템을 모르는 순수 변환이라 단위 테스트로 검증된다
 * ({@code batch/} 가 파서와 클라이언트를 가른 것과 같은 이유).
 *
 * <p>기획서 4-3 의 세 가지를 여기서 한다:
 * <ol>
 *   <li><b>EXIF 스트립</b> — 원본 EXIF 에는 GPS 좌표가 들어 있다. 3-3 에서 좌표를 저장하지 않기로
 *       했으므로 남겨 둘 이유가 없다. 래스터를 새로 구워 메타데이터 없이 쓰면 통째로 사라진다.</li>
 *   <li><b>Orientation 보정</b> — 버리기 전에 이 태그만 읽어 픽셀에 반영한다({@link ExifOrientation}).</li>
 *   <li><b>리사이즈</b> — 스마트폰 사진 1장이 3~8MB 라 원본 보관은 낭비다.</li>
 * </ol>
 *
 * <p><b>HEIC 는 여기서 처리하지 않는다.</b> JDK ImageIO 에 디코더가 없다. Android 우선 출시라
 * 당장 급하지 않고, 넣는다면 디코더를 붙이는 별도 작업이다 — 호출부가 미리 걸러 안내한다.
 */
public final class PhotoTransform {

    private PhotoTransform() {
    }

    /**
     * @param source   업로드된 원본 바이트
     * @param maxEdge  긴 변 목표 픽셀. 원본이 이보다 작으면 <b>확대하지 않는다</b>
     * @param quality  JPEG 품질 0.0~1.0
     * @throws UnsupportedImageException 디코더가 없거나 이미지가 아닐 때
     */
    public static byte[] toJpeg(byte[] source, int maxEdge, float quality) {
        BufferedImage decoded = decode(source);
        BufferedImage flattened = flatten(decoded);
        BufferedImage oriented = orient(flattened, ExifOrientation.read(source));
        BufferedImage scaled = scale(oriented, maxEdge);
        return encode(scaled, quality);
    }

    private static BufferedImage decode(byte[] source) {
        try {
            BufferedImage image = ImageIO.read(new ByteArrayInputStream(source));
            if (image == null) {
                // ImageIO 는 "못 읽었다"를 예외가 아니라 null 로 알린다. 그대로 흘리면
                // 한참 뒤 NPE 로 터져서 원인이 업로드 파일이라는 걸 못 알아본다.
                throw new UnsupportedImageException("이미지를 해석할 수 없습니다");
            }
            return image;
        } catch (IOException e) {
            throw new UnsupportedImageException("이미지를 읽는 중 오류가 발생했습니다", e);
        }
    }

    /**
     * 투명도를 흰 배경으로 눕힌다. PNG 를 알파째로 JPEG 에 넘기면 투명 부분이 <b>검게</b> 나온다 —
     * JPEG 에 알파 채널이 없어서다.
     */
    private static BufferedImage flatten(BufferedImage source) {
        BufferedImage rgb = new BufferedImage(
                source.getWidth(), source.getHeight(), BufferedImage.TYPE_INT_RGB);
        Graphics2D g = rgb.createGraphics();
        try {
            g.setColor(Color.WHITE);
            g.fillRect(0, 0, rgb.getWidth(), rgb.getHeight());
            g.drawImage(source, 0, 0, null);
        } finally {
            g.dispose();
        }
        return rgb;
    }

    /** EXIF orientation 1~8 을 픽셀에 반영한다. 5~8 은 가로세로가 바뀐다. */
    static BufferedImage orient(BufferedImage source, int orientation) {
        if (!ExifOrientation.transforms(orientation)) {
            return source;
        }

        int w = source.getWidth();
        int h = source.getHeight();
        boolean swapsAxes = orientation >= 5;

        // AffineTransform(m00, m10, m01, m11, m02, m12) — 원본 좌표를 결과 좌표로 보내는 행렬이다.
        AffineTransform tx = switch (orientation) {
            case 2 -> new AffineTransform(-1, 0, 0, 1, w, 0);   // 좌우 반전
            case 3 -> new AffineTransform(-1, 0, 0, -1, w, h);  // 180도
            case 4 -> new AffineTransform(1, 0, 0, -1, 0, h);   // 상하 반전
            case 5 -> new AffineTransform(0, 1, 1, 0, 0, 0);    // 전치
            case 6 -> new AffineTransform(0, 1, -1, 0, h, 0);   // 시계 90도 (세로로 찍은 사진 대부분)
            case 7 -> new AffineTransform(0, -1, -1, 0, h, w);  // 역전치
            default -> new AffineTransform(0, -1, 1, 0, 0, w);  // 8 — 반시계 90도
        };

        BufferedImage target = new BufferedImage(
                swapsAxes ? h : w, swapsAxes ? w : h, BufferedImage.TYPE_INT_RGB);
        // 90도 배수와 반전뿐이라 픽셀이 격자에 딱 떨어진다. NEAREST 로 충분하고 흐려지지도 않는다.
        return new AffineTransformOp(tx, AffineTransformOp.TYPE_NEAREST_NEIGHBOR)
                .filter(source, target);
    }

    /**
     * 긴 변을 {@code maxEdge} 로 맞춘다.
     *
     * <p><b>절반씩 줄여 내려간 뒤 마지막만 바이큐빅이다.</b> 4000px 을 1280 으로 한 번에 줄이면
     * 원본 픽셀을 드문드문 집어서 비늘·지느러미 같은 가는 무늬가 계단으로 깨진다(에일리어싱).
     * 도감 표지로 쓸 사진이라 이 차이가 눈에 띈다.
     */
    static BufferedImage scale(BufferedImage source, int maxEdge) {
        int w = source.getWidth();
        int h = source.getHeight();
        int longEdge = Math.max(w, h);
        if (longEdge <= maxEdge) {
            return source;   // 확대는 하지 않는다 — 없는 정보를 만들어 낼 뿐이고 용량만 는다
        }

        double ratio = (double) maxEdge / longEdge;
        int targetW = Math.max(1, (int) Math.round(w * ratio));
        int targetH = Math.max(1, (int) Math.round(h * ratio));

        BufferedImage current = source;
        while (current.getWidth() / 2 > targetW && current.getHeight() / 2 > targetH) {
            current = redraw(current, current.getWidth() / 2, current.getHeight() / 2,
                    RenderingHints.VALUE_INTERPOLATION_BILINEAR);
        }
        return redraw(current, targetW, targetH, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
    }

    private static BufferedImage redraw(BufferedImage source, int width, int height,
                                        Object interpolation) {
        BufferedImage target = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = target.createGraphics();
        try {
            g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, interpolation);
            g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
            g.drawImage(source, 0, 0, width, height, null);
        } finally {
            g.dispose();
        }
        return target;
    }

    /**
     * JPEG 로 굽는다. {@link IIOImage} 에 메타데이터를 {@code null} 로 넘기므로
     * <b>EXIF 는 여기서 사라진다</b> — 별도의 스트립 단계가 따로 있는 게 아니다.
     */
    private static byte[] encode(BufferedImage image, float quality) {
        Iterator<ImageWriter> writers = ImageIO.getImageWritersByFormatName("jpeg");
        if (!writers.hasNext()) {
            throw new IllegalStateException("JPEG writer 를 찾을 수 없습니다");
        }
        ImageWriter writer = writers.next();

        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try (ImageOutputStream stream = ImageIO.createImageOutputStream(out)) {
            ImageWriteParam param = writer.getDefaultWriteParam();
            param.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
            param.setCompressionQuality(quality);

            writer.setOutput(stream);
            writer.write(null, new IIOImage(image, null, null), param);
        } catch (IOException e) {
            throw new UnsupportedImageException("이미지를 저장하는 중 오류가 발생했습니다", e);
        } finally {
            writer.dispose();
        }
        return out.toByteArray();
    }
}
