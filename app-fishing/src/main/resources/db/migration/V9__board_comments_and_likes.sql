-- 댓글과 좋아요.
--
-- V3 는 fishing_posts 에 like_count·comment_count 를 두었지만 **그 뒤에 아무것도 없었다** —
-- V4 시드가 24, 8 같은 숫자를 그냥 박아 넣었을 뿐이라 화면의 "댓글 8" 을 눌러도 볼 것이 없었다.
-- 여기서 실체를 만든다.

CREATE TABLE fishing_post_comments (
    id              BIGSERIAL PRIMARY KEY,
    post_id         BIGINT NOT NULL REFERENCES fishing_posts(id) ON DELETE CASCADE,

    -- 댓글은 로그인해야 쓴다. 글(user_id NULL 허용)과 달리 익명 시드가 없다.
    user_id         BIGINT NOT NULL,

    -- 글과 같은 이유로 작성 시점 닉네임을 박아 둔다 (auth-service 를 되부르지 않는다).
    author_nickname VARCHAR(30) NOT NULL,

    content         VARCHAR(500) NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

-- 한 글의 댓글을 시간순으로 읽는다. 목록의 개수 세기도 이 인덱스를 탄다.
CREATE INDEX idx_post_comments_post ON fishing_post_comments(post_id, created_at);

CREATE TABLE fishing_post_likes (
    post_id    BIGINT NOT NULL REFERENCES fishing_posts(id) ON DELETE CASCADE,
    user_id    BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now(),

    -- 같은 사람이 같은 글을 두 번 좋아할 수 없다. 토글이 두 번 눌려도 DB 가 막는다.
    PRIMARY KEY (post_id, user_id)
);

-- "내가 좋아요한 글" 을 목록에서 한 번에 읽는다.
CREATE INDEX idx_post_likes_user ON fishing_post_likes(user_id);

-- 시드가 박아 둔 가짜 수치를 되돌린다.
--
-- 이제 두 컬럼은 위 두 표를 세어 유지하는 값이다. 남겨 두면 댓글 0개인 글이
-- "댓글 8" 로 보이는 상태가 그대로 굳는다 — 실제로 그것 때문에 눌러도 반응이 없다는
-- 보고가 나왔다.
UPDATE fishing_posts SET like_count = 0, comment_count = 0;
