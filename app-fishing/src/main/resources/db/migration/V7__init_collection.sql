-- 도감(어종 마스터 + 조과 기록). 기획서 v2 3-2 / 3-3.
--
-- 진행도 요약 테이블은 두지 않는다 — 사용자당 조과 레코드가 수천 건을 넘길 일이 없어
-- DISTINCT species_id 집계로 충분하고, 요약 테이블은 조기 최적화다.

CREATE TABLE fishing_species (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(30) NOT NULL,   -- "감성돔"
    name_sci        VARCHAR(60),            -- "Acanthopagrus schlegelii"
    habitat         VARCHAR(10) NOT NULL,   -- SEA | FRESH  (대문자 코드. 한글이면 프론트 Habitat.fromCode가 전부 SEA로 폴백)
    rarity          VARCHAR(10) NOT NULL DEFAULT 'COMMON',  -- COMMON | UNCOMMON | RARE
    -- 「수산자원관리법 시행령」기준의 참고값이다. 앱은 위법 여부를 판정하지 않고 정보로만 노출한다(기획서 7장).
    min_legal_size  DECIMAL(4,1),           -- 포획금지체장 cm
    closed_season   VARCHAR(50),            -- 금어기 "12/01~01/31"
    -- 제철. 기획서 3-2 스키마에는 없지만 프론트 Species.season / 도감 상세 표가 이미 쓴다.
    season          VARCHAR(20),            -- "9월 ~ 12월", "연중"
    description     VARCHAR(500),
    -- 컬러 일러스트 경로. 에셋 확보 전까지 NULL이며, 이때 도감 칸은 사용자 인증샷을 표지로 쓴다.
    illust_path     VARCHAR(200),
    display_order   INT NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    UNIQUE (name)
);

CREATE INDEX idx_species_order ON fishing_species(display_order);

-- user_id는 auth 스키마 users를 참조하지만 FK는 걸지 않는다 (V1 fishing_user_favorites와 같은 이유).
--
-- GPS 좌표는 저장하지 않는다 — 자동 판별을 하지 않으니 기능적으로 필요 없고,
-- 낚시 포인트 좌표는 민감 정보라 보관 자체가 부담이다. 장소는 spot_name 자유 텍스트로 충분하다.
-- (업로드 사진의 EXIF GPS도 저장 전에 스트립한다 — 기획서 4-3)
CREATE TABLE fishing_user_catches (
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT NOT NULL,
    species_id       BIGINT NOT NULL REFERENCES fishing_species(id),
    -- 기획서상 인증샷은 필수지만, 프론트가 아직 image_picker를 붙이지 않아
    -- (FeatureFlags.enablePhotoPicker = false) 사진 없이 등록되는 경로가 살아 있다.
    -- NOT NULL을 지금 걸면 유일한 클라이언트가 등록을 못 한다. 피커가 붙으면 서비스단에서 필수로 막는다.
    photo_url        VARCHAR(300),
    length_cm        DECIMAL(4,1) NOT NULL,  -- 사용자 직접 입력. 서버는 검증하지 않고 기록만 한다
    weight_g         INT,
    caught_at        TIMESTAMP NOT NULL DEFAULT now(),
    region_group_id  BIGINT REFERENCES fishing_regions(id),
    spot_name        VARCHAR(50),            -- 등록 포인트가 아닐 수 있어 자유 입력이다
    memo             VARCHAR(300),
    created_at       TIMESTAMP NOT NULL DEFAULT now()
);

-- 도감 집계(어종별 보유 여부·최고 기록)와 내 기록 목록이 각각 타는 인덱스
CREATE INDEX idx_catches_user_species ON fishing_user_catches(user_id, species_id);
CREATE INDEX idx_catches_user_created ON fishing_user_catches(user_id, created_at DESC);
