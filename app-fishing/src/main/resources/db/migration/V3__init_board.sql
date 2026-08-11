-- 게시판. 가이드 9장에 따라 board-lib 로 빼지 않고 app-fishing 안에 직접 만든다.
-- 재사용 대상이 아직 낚시 앱 하나뿐이라 공통점을 뽑을 근거가 부족하다 — 두 번째 앱을 만들 때
-- 실제 차이를 보고 추출한다.

CREATE TABLE fishing_posts (
    id               BIGSERIAL PRIMARY KEY,
    category         VARCHAR(10) NOT NULL,   -- CATCH|FREE|QUESTION (한글 라벨 금지)
    title            VARCHAR(100) NOT NULL,
    content          TEXT NOT NULL,

    -- 작성자. Step 9(인증)에서 user_id 가 실제로 채워지고, 그 전까지는 닉네임만 쓴다.
    -- auth 스키마 users 를 참조하지만 FK 는 걸지 않는다 (서비스별 스키마 독립성).
    user_id          BIGINT,
    author_nickname  VARCHAR(30) NOT NULL DEFAULT '익명',

    -- NULL 이면 지역 없는 글이다. 프론트는 regionName 이 null 이면 "전체" 로 표시한다.
    region_group_id  BIGINT REFERENCES fishing_regions(id),

    like_count       INT NOT NULL DEFAULT 0,
    comment_count    INT NOT NULL DEFAULT 0,
    has_image        BOOLEAN NOT NULL DEFAULT false,
    created_at       TIMESTAMP NOT NULL DEFAULT now()
);

-- 목록은 항상 최신순이고 태그 탭으로 거른다.
CREATE INDEX idx_posts_created ON fishing_posts(created_at DESC);
CREATE INDEX idx_posts_category_created ON fishing_posts(category, created_at DESC);
CREATE INDEX idx_posts_region ON fishing_posts(region_group_id);
