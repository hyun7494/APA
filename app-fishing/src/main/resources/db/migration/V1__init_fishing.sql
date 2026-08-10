CREATE TABLE fishing_regions (
    id      BIGSERIAL PRIMARY KEY,
    name    VARCHAR(30) NOT NULL,   -- "부산 기장"
    area    VARCHAR(30) NOT NULL,   -- "부산광역시"
    UNIQUE (name)
);

CREATE TABLE fishing_spots (
    id                BIGSERIAL PRIMARY KEY,
    name              VARCHAR(50) NOT NULL,
    region_group_id   BIGINT NOT NULL REFERENCES fishing_regions(id),
    -- 공공 API 조회용 좌표. 기상청은 위경도가 아니라 격자를 쓴다
    latitude          DECIMAL(9,6),
    longitude         DECIMAL(9,6),
    grid_nx           INT,
    grid_ny           INT,
    khoa_obs_code     VARCHAR(20),  -- 국립해양조사원 관측소 코드 (물때·수온)

    rating            VARCHAR(10) NOT NULL DEFAULT 'NORMAL',  -- VERY_GOOD|GOOD|NORMAL|BAD
    water_temp        DECIMAL(4,1),
    wave_height       DECIMAL(3,1),
    wind_speed        DECIMAL(4,1),
    weather           VARCHAR(20),
    tide_info         VARCHAR(30),   -- "5물 · 만조 13:20"
    sunrise_sunset    VARCHAR(20),   -- "05:11 / 19:42"
    comment           VARCHAR(200),
    hourly_forecast   JSONB,         -- [55,70,82,76,68,60] 길이 6 고정
    recommended_fish  JSONB,         -- ["감성돔","벵에돔"]
    updated_at        TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_spots_region ON fishing_spots(region_group_id);

CREATE TABLE fishing_daily_fortune (
    id              BIGSERIAL PRIMARY KEY,
    fortune_date    DATE NOT NULL,
    zodiac          VARCHAR(10) NOT NULL,   -- RAT ~ PIG (대문자 코드. 한글로 넣으면 프론트 매칭 실패)
    score           INT NOT NULL,
    total_comment   VARCHAR(200),
    love            VARCHAR(200),
    money           VARCHAR(200),
    fishing         VARCHAR(200),
    health          VARCHAR(200),
    lucky_direction VARCHAR(10),
    lucky_time      VARCHAR(20),
    UNIQUE (fortune_date, zodiac)
);

-- user_id는 auth 스키마 users를 참조하지만 FK는 걸지 않는다.
-- 서비스별 스키마 독립성 유지
CREATE TABLE fishing_user_favorites (
    user_id         BIGINT NOT NULL,
    region_group_id BIGINT NOT NULL REFERENCES fishing_regions(id),
    created_at      TIMESTAMP NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, region_group_id)
);

CREATE TABLE fishing_user_zodiac (
    user_id BIGINT PRIMARY KEY,
    zodiac  VARCHAR(10) NOT NULL
);
