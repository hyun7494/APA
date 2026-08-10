CREATE TABLE users (
                       id BIGSERIAL PRIMARY KEY,
                       social_type VARCHAR(10) NOT NULL,
                       social_id VARCHAR(100) NOT NULL,
                       nickname VARCHAR(30) NOT NULL,
                       profile_url VARCHAR(500),
                       status VARCHAR(10) NOT NULL DEFAULT 'ACTIVE',
                       withdrawn_at TIMESTAMP,
                       created_at TIMESTAMP NOT NULL DEFAULT now(),
                       updated_at TIMESTAMP NOT NULL DEFAULT now(),
                       UNIQUE (social_type, social_id)
);

CREATE TABLE user_fcm_tokens (
                                 id BIGSERIAL PRIMARY KEY,
                                 user_id BIGINT NOT NULL REFERENCES users(id),
                                 app_id VARCHAR(20) NOT NULL,
                                 token VARCHAR(255) NOT NULL,
                                 updated_at TIMESTAMP NOT NULL DEFAULT now(),
                                 UNIQUE (user_id, app_id, token)
);

CREATE TABLE refresh_tokens (
                                id BIGSERIAL PRIMARY KEY,
                                user_id BIGINT NOT NULL REFERENCES users(id),
                                token_hash VARCHAR(255) NOT NULL,
                                app_id VARCHAR(20),
                                expires_at TIMESTAMP NOT NULL,
                                created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE user_app_links (
                                user_id BIGINT NOT NULL REFERENCES users(id),
                                app_id VARCHAR(20) NOT NULL,
                                first_login_at TIMESTAMP NOT NULL DEFAULT now(),
                                last_login_at TIMESTAMP NOT NULL DEFAULT now(),
                                PRIMARY KEY (user_id, app_id)
);