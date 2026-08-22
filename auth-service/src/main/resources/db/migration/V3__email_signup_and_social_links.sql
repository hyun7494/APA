-- 자체 회원가입(이메일+비밀번호)과 소셜 계정 연동.
--
-- V1 은 "계정 = 소셜 신원 하나"였다. users 에 (social_type, social_id) 가 NOT NULL 로 박혀
-- 있어서 ① 소셜 없이 가입할 수 없고 ② 한 사람이 카카오와 구글을 함께 쓸 수도 없었다.
-- 소셜 신원을 users 밖으로 꺼내 1:N 으로 바꾼다.

-- 1) 자체 가입 수단. 소셜로만 들어온 기존 계정은 둘 다 NULL 로 남는다.
ALTER TABLE users ADD COLUMN email VARCHAR(255);
ALTER TABLE users ADD COLUMN password_hash VARCHAR(100);

-- 제공자(또는 우리)가 소유를 확인해 준 주소인가.
-- 확인되지 않은 주소로 계정을 이어 붙이면, 남의 주소로 먼저 가입해 둔 사람이
-- 진짜 주인의 소셜 로그인을 자기 계정으로 삼킬 수 있다.
ALTER TABLE users ADD COLUMN email_verified BOOLEAN NOT NULL DEFAULT false;

-- 이메일은 로그인 아이디다. 애플리케이션에서 소문자로 내려 쓴 뒤 넣는다.
ALTER TABLE users ADD CONSTRAINT uq_users_email UNIQUE (email);

-- 비밀번호만 있고 이메일이 없는 계정은 로그인할 방법이 없다.
ALTER TABLE users ADD CONSTRAINT ck_users_password_needs_email
    CHECK (password_hash IS NULL OR email IS NOT NULL);

-- 2) 소셜 신원 (계정 1 : 연결 N)
CREATE TABLE user_social_accounts (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    social_type VARCHAR(10) NOT NULL,
    social_id VARCHAR(100) NOT NULL,
    -- 제공자가 준 주소. users.email 과 다를 수 있어 따로 남긴다 (연동 이력 추적용).
    email VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    -- 한 소셜 계정이 두 사람에게 붙으면 안 된다.
    CONSTRAINT uq_user_social_accounts_identity UNIQUE (social_type, social_id),
    -- 한 사람이 같은 제공자를 두 번 붙일 수도 없다. 붙이면 어느 쪽으로 들어왔는지에 따라
    -- 프로필이 오락가락한다.
    CONSTRAINT uq_user_social_accounts_provider UNIQUE (user_id, social_type)
);

CREATE INDEX idx_user_social_accounts_user_id ON user_social_accounts (user_id);

-- 3) 기존 소셜 신원을 그대로 옮긴다. V1 에서 두 컬럼 모두 NOT NULL 이었으므로 전부 유효하다.
INSERT INTO user_social_accounts (user_id, social_type, social_id, created_at)
SELECT id, social_type, social_id, created_at FROM users;

-- 4) 옮겼으니 users 에서 뺀다. UNIQUE (social_type, social_id) 는 컬럼과 함께 사라진다.
ALTER TABLE users DROP COLUMN social_type;
ALTER TABLE users DROP COLUMN social_id;
