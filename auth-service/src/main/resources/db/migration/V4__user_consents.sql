-- 약관 동의 기록.
--
-- 지금까지 동의를 **받은 적이 없다.** 로그인·회원가입 화면이 "가입하면 서비스 이용약관과
-- 개인정보 처리방침에 동의하는 것으로 봅니다" 라는 회색 문구만 띄웠는데, 그건
-- ① 읽을 문서가 어디에도 없었고 ② 개인정보보호법이 요구하는 **명시적 동의**가 아니며
-- ③ 나중에 "동의한 적 없다" 는 주장에 내놓을 근거가 하나도 없다는 뜻이었다.
--
-- ★ **덧붙이기만 하는 표다 (append-only).** 동의를 지우거나 덮어쓰지 않는다 —
--    현재 상태는 (user_id, consent_type) 별 **가장 최근 행**이다.
--    철회 이력이 남아야 하는 게 핵심이다. 특히 마케팅 수신은 "언제 동의했고 언제
--    철회했는지" 를 댈 수 있어야 한다. 한 행을 UPDATE 해 버리면 그 이력이 사라진다.
--
-- 계정 단위라 fishing 이 아니라 auth 스키마에 둔다. 가입 시점에 받고, 계정 하나가
-- 여러 앱(APA 공통 계정)에서 쓰이기 때문이다.

CREATE TABLE user_consents (
    id             BIGSERIAL PRIMARY KEY,
    user_id        BIGINT       NOT NULL REFERENCES users (id),

    -- TERMS_OF_SERVICE | PRIVACY_POLICY | AGE_14 | MARKETING
    -- 코드를 enum 이 아니라 문자열로 둔다 — 항목이 늘 때 마이그레이션이 필요 없다.
    consent_type   VARCHAR(40)  NOT NULL,

    -- 동의한 문서의 판. 약관이 바뀌면 판이 올라가고 재동의를 받아야 한다.
    -- 어느 판에 동의했는지 남지 않으면 "그때 뭐에 동의한 거냐" 에 답할 수 없다.
    version        VARCHAR(20)  NOT NULL,

    -- 철회도 행으로 남는다. false 가 "동의 안 함" 이고, 행이 없는 것은 "묻지 않음" 이다.
    agreed         BOOLEAN      NOT NULL,

    agreed_at      TIMESTAMP    NOT NULL DEFAULT now()
);

-- 현재 상태를 물을 때 쓰는 축이다 — (user, type) 으로 좁힌 뒤 최신 한 행을 본다.
CREATE INDEX idx_user_consents_lookup
    ON user_consents (user_id, consent_type, agreed_at DESC);

-- ⚠️ UNIQUE (user_id, consent_type) 을 걸지 않는다. 걸면 재동의·철회를 못 쌓는다.
