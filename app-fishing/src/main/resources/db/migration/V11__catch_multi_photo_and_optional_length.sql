-- 조과 등록을 시안에 맞춘다 (6-J 에서 "서버가 못 받아서" 미뤄 둔 셋).
--
-- 원래 V9 로 예정돼 있었으나 그 번호를 게시판 댓글·좋아요가 먼저 썼다. 항목은 그대로다.

-- ① 메모 500자. 시안이 500 인데 컬럼이 300 이라 프론트가 300 으로 맞춰 두고 있었다.
ALTER TABLE fishing_user_catches ALTER COLUMN memo TYPE VARCHAR(500);

-- ② 길이는 선택이다.
--
-- 시안의 라벨이 `길이 (선택)` 인데 NOT NULL 이라 프론트가 필수로 막고 있었다.
-- 놓아준 물고기나 사진만 남기고 싶은 기록이 있다 — 길이를 모른다고 등록을 막을 이유가 없다.
-- 도감의 "최고 기록" 은 길이가 있는 기록 중에서만 고르면 된다.
ALTER TABLE fishing_user_catches ALTER COLUMN length_cm DROP NOT NULL;

-- ③ 사진 여러 장 (시안 `PHOTOS · 1 / 5`).
--
-- 단일 컬럼으로는 못 담아서 표를 나눈다. 배열 컬럼 대신 표를 쓰는 이유는 순서를 명시적으로
-- 들고 있어야 해서다 — 첫 장이 도감 칸의 표지가 된다.
CREATE TABLE fishing_catch_photos (
    catch_id   BIGINT NOT NULL REFERENCES fishing_user_catches(id) ON DELETE CASCADE,
    photo_url  VARCHAR(300) NOT NULL,

    -- 0 부터. JPA @OrderColumn 이 관리한다.
    sort_order INT NOT NULL,

    PRIMARY KEY (catch_id, sort_order)
);

-- "이 사진이 내 것인가" 를 매 요청 확인한다 (PhotoController 의 소유자 검사).
CREATE INDEX idx_catch_photos_url ON fishing_catch_photos (photo_url);

-- 기존 사진을 첫 장으로 옮긴다.
INSERT INTO fishing_catch_photos (catch_id, photo_url, sort_order)
SELECT id, photo_url, 0 FROM fishing_user_catches WHERE photo_url IS NOT NULL;

ALTER TABLE fishing_user_catches DROP COLUMN photo_url;
