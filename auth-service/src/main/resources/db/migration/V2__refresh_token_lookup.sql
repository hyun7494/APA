-- 리프레시 토큰은 해시로 조회한다. V1 에는 인덱스가 없어서 전체 스캔이 되고,
-- 무엇보다 같은 해시가 두 줄 생기는 것을 막을 수단이 없었다.
--
-- 원문이 아니라 SHA-256 해시를 넣는 이유: DB 가 새면 저장된 값 그대로 재발급에
-- 쓸 수 있으면 안 된다. 해시는 길이가 고정(64자 hex)이라 컬럼 폭도 낭비가 없다.
ALTER TABLE refresh_tokens
    ADD CONSTRAINT uq_refresh_tokens_token_hash UNIQUE (token_hash);

-- 로그아웃·회전에서 "이 사용자의 토큰 전부"를 지운다.
CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens (user_id);

-- 만료된 줄을 주기적으로 걷어낼 때 쓴다.
CREATE INDEX idx_refresh_tokens_expires_at ON refresh_tokens (expires_at);
