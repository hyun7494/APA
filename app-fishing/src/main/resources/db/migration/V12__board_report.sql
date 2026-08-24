-- 게시글 신고 (계약서 3-8 의 마지막 남은 항목).
--
-- ⚠️ 지금은 **읽는 쪽이 없다.** 운영자 화면이 없어서 신고는 이 표에 쌓이기만 한다.
-- 그래도 먼저 만드는 이유는 둘이다 — (1) 사용자가 신고할 창구 없이 UGC 앱을 스토어에
-- 올릴 수 없고, (2) 운영 도구를 붙일 때 그동안의 신고가 남아 있어야 쓸모가 있다.
-- 나중에 볼 것을 지금 안 쌓으면 그때 표는 비어 있다.

CREATE TABLE fishing_post_reports (
    id         BIGSERIAL PRIMARY KEY,
    post_id    BIGINT NOT NULL REFERENCES fishing_posts(id) ON DELETE CASCADE,

    -- 신고는 로그인해야 한다. 익명 신고를 받으면 한 사람이 몇 번이고 누를 수 있어
    -- 아래 UNIQUE 가 의미를 잃는다.
    user_id    BIGINT NOT NULL,

    -- ReportReason enum 의 이름. VARCHAR 로 두는 것은 게시글 category 와 같은 이유다 —
    -- 항목이 늘 때 DB 타입을 고치지 않아도 된다.
    reason     VARCHAR(20) NOT NULL,

    -- `기타` 를 골랐을 때 무엇이 문제인지. 나머지 사유에서는 선택이다.
    detail     VARCHAR(300),

    created_at TIMESTAMP NOT NULL DEFAULT now(),

    -- 같은 사람이 같은 글을 두 번 신고하지 않는다. 좋아요(V9)와 같은 장치인데
    -- 여기서는 더 중요하다 — 막지 않으면 한 사람이 연타해서 신고 수를 부풀린다.
    UNIQUE (post_id, user_id)
);

-- 운영 도구가 붙으면 "이 글에 신고가 몇 건" 을 최신순으로 읽는다.
CREATE INDEX idx_post_reports_post ON fishing_post_reports(post_id, created_at);
