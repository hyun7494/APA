package com.apa.fishing.photo;

/**
 * JPEG 의 EXIF Orientation(0x0112) 태그만 읽는다. 순수 함수라 키·파일 없이 테스트된다.
 *
 * <p><b>왜 라이브러리를 안 쓰나.</b> 저장 파이프라인이 EXIF 에서 필요로 하는 값은 이 태그 하나뿐이다
 * (나머지는 전부 버린다 — 기획서 4-3 EXIF 스트립). 태그 하나 때문에 메타데이터 라이브러리를
 * 물고 들어오는 대신 APP1 세그먼트만 직접 훑는다.
 *
 * <p><b>왜 필요한가.</b> 스마트폰은 센서를 돌려 찍어도 픽셀은 그대로 두고 "몇 도 돌려서 보라"는
 * 태그만 남긴다. 우리는 리사이즈하며 픽셀을 새로 굽고 EXIF 를 통째로 버리므로, 이 값을 미리
 * 읽어 픽셀에 반영하지 않으면 <b>세로로 찍은 사진이 전부 눕는다.</b>
 */
public final class ExifOrientation {

    /** 회전·반전 없음. 태그가 없거나 못 읽으면 이 값이다 — 억지로 돌리는 것보다 그대로 두는 게 안전하다. */
    public static final int NORMAL = 1;

    private static final int MARKER = 0xFF;
    private static final int SOI = 0xD8;   // Start of Image
    private static final int APP1 = 0xE1;  // EXIF 가 들어 있는 세그먼트
    private static final int SOS = 0xDA;   // Start of Scan — 여기부터는 압축 데이터라 더 볼 게 없다
    private static final int TAG_ORIENTATION = 0x0112;
    private static final byte[] EXIF_ID = {'E', 'x', 'i', 'f', 0, 0};

    private ExifOrientation() {
    }

    /**
     * @return 1~8 의 orientation. JPEG 이 아니거나 태그가 없거나 잘린 파일이면 {@link #NORMAL}
     */
    public static int read(byte[] image) {
        if (image == null || image.length < 4) {
            return NORMAL;
        }
        if (u8(image, 0) != MARKER || u8(image, 1) != SOI) {
            return NORMAL;   // PNG 등. EXIF 자체가 없다
        }

        int pos = 2;
        while (pos + 4 <= image.length) {
            if (u8(image, pos) != MARKER) {
                return NORMAL;   // 세그먼트 경계가 어긋났다 — 더 파고들면 엉뚱한 값을 읽는다
            }
            int marker = u8(image, pos + 1);
            if (marker == SOS) {
                return NORMAL;
            }
            // 길이 필드는 자기 자신(2바이트)을 포함한다
            int length = u16(image, pos + 2, false);
            if (length < 2 || pos + 2 + length > image.length) {
                return NORMAL;   // 잘린 파일
            }
            if (marker == APP1 && startsWithExifId(image, pos + 4)) {
                return readFromTiff(image, pos + 4 + EXIF_ID.length, pos + 2 + length);
            }
            pos += 2 + length;
        }
        return NORMAL;
    }

    /** orientation 값이 픽셀을 실제로 건드려야 하는 값인지. 1 이면 리샘플링을 건너뛴다. */
    public static boolean transforms(int orientation) {
        return orientation >= 2 && orientation <= 8;
    }

    private static boolean startsWithExifId(byte[] image, int offset) {
        if (offset + EXIF_ID.length > image.length) {
            return false;
        }
        for (int i = 0; i < EXIF_ID.length; i++) {
            if (image[offset + i] != EXIF_ID[i]) {
                return false;
            }
        }
        return true;
    }

    /**
     * TIFF 헤더 → IFD0 → Orientation 태그.
     *
     * <p>TIFF 안의 오프셋은 전부 <b>TIFF 헤더 기준 상대값</b>이다 (파일 기준이 아니다).
     * 이걸 파일 오프셋으로 착각하면 APP1 앞 바이트 수만큼 어긋난 데이터를 읽는다.
     */
    private static int readFromTiff(byte[] image, int tiffStart, int segmentEnd) {
        if (tiffStart + 8 > segmentEnd) {
            return NORMAL;
        }

        boolean littleEndian;
        int byteOrder = u16(image, tiffStart, false);
        if (byteOrder == 0x4949) {          // "II"
            littleEndian = true;
        } else if (byteOrder == 0x4D4D) {   // "MM"
            littleEndian = false;
        } else {
            return NORMAL;
        }
        if (u16(image, tiffStart + 2, littleEndian) != 42) {
            return NORMAL;   // TIFF 매직이 아니다
        }

        int ifdOffset = (int) u32(image, tiffStart + 4, littleEndian);
        int ifd = tiffStart + ifdOffset;
        if (ifd + 2 > segmentEnd || ifd < tiffStart) {
            return NORMAL;
        }

        int entryCount = u16(image, ifd, littleEndian);
        for (int i = 0; i < entryCount; i++) {
            int entry = ifd + 2 + i * 12;
            if (entry + 12 > segmentEnd) {
                return NORMAL;
            }
            if (u16(image, entry, littleEndian) != TAG_ORIENTATION) {
                continue;
            }
            // SHORT 1개라 값이 오프셋 자리(entry+8)에 그대로 들어 있다.
            // 리틀엔디언이면 앞 2바이트, 빅엔디언이어도 4바이트 필드의 앞 2바이트가 값이다.
            int value = u16(image, entry + 8, littleEndian);
            return (value >= 1 && value <= 8) ? value : NORMAL;
        }
        return NORMAL;
    }

    private static int u8(byte[] data, int i) {
        return data[i] & 0xFF;
    }

    private static int u16(byte[] data, int i, boolean littleEndian) {
        if (i + 2 > data.length) {
            return 0;
        }
        return littleEndian
                ? u8(data, i) | (u8(data, i + 1) << 8)
                : (u8(data, i) << 8) | u8(data, i + 1);
    }

    private static long u32(byte[] data, int i, boolean littleEndian) {
        if (i + 4 > data.length) {
            return 0;
        }
        return littleEndian
                ? u8(data, i) | ((long) u8(data, i + 1) << 8)
                        | ((long) u8(data, i + 2) << 16) | ((long) u8(data, i + 3) << 24)
                : ((long) u8(data, i) << 24) | ((long) u8(data, i + 1) << 16)
                        | ((long) u8(data, i + 2) << 8) | u8(data, i + 3);
    }
}
