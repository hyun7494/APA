#!/bin/bash
# 앱이 쓸 DB 역할을 만든다. **슈퍼유저가 아니다.**
#
# ★ 왜 이걸 두는가 — postgres 이미지는 `POSTGRES_USER` 를 **부트스트랩 슈퍼유저**로
#   만든다. 앱이 그 계정을 그대로 쓰면, 앱이 한 번 뚫렸을 때 DB 전체를 잃는다.
#   슈퍼유저는 `COPY ... FROM PROGRAM` 으로 **DB 컨테이너 안에서 명령을 실행**할 수 있고,
#   서버 파일을 읽으며, 모든 권한 검사를 건너뛴다. SQL 인젝션이 지금은 없지만,
#   있는 날 피해 범위가 통째로 달라진다.
#
# 그래서 역할을 둘로 가른다:
#   - 관리자(POSTGRES_USER)  슈퍼유저. 부트스트랩과 사람이 하는 유지보수용
#   - 앱(APP_DB_USER)        NOSUPERUSER. 자기 DB 만 다룬다
#
# ⚠️ 앱 역할은 **자기 DB 의 소유자**다. Flyway 가 스키마와 표를 만들어야 하기 때문이다
#    (CREATE ON DATABASE 가 필요하다). 소유자라도 슈퍼유저가 아닌 것이 요점이다 —
#    자기 데이터는 다룰 수 있지만 서버를 어쩌지는 못한다.
#
# ⚠️ 이 스크립트는 **데이터 디렉터리가 비어 있을 때만** 돈다 (postgres 이미지 규칙).
#    이미 쓰던 볼륨에 적용하려면 `docker volume rm apa_pgdata` 로 한 번 비워야 한다
#    (사진 볼륨 `apa_photos` 는 건드리지 말 것). README 의 "DB 역할" 절 참고.
set -euo pipefail

: "${APP_DB_USER:?APP_DB_USER 가 필요하다}"
: "${APP_DB_PASSWORD:?APP_DB_PASSWORD 가 필요하다}"

# ⚠️ **psql 변수는 `-c` 로 준 명령에서는 치환되지 않는다.** `-c 'ALTER ROLE :"x"'` 는
#    그대로 서버로 가서 `syntax error at or near ":"` 가 난다. 표준입력(또는 파일)으로
#    넘겨야 psql 의 렉서가 치환한다. 실제로 이걸 몰라 한 번 부팅에 실패했다.
#
#    또 하나 — 변수는 **따옴표 안에서는 치환되지 않는다.** 그래서 `DO $$ ... $$` 블록
#    안에서는 못 쓰고, 조건 분기를 SQL 이 아니라 여기 셸에서 한다.
#    (`:"x"` 는 식별자로, `:'x'` 는 문자열로 psql 이 안전하게 따옴표를 붙여 준다.)
psql_in() {
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
         -v app_user="$APP_DB_USER" -v app_password="$APP_DB_PASSWORD" \
         -v db_name="$POSTGRES_DB"
}

exists=$(psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$APP_DB_USER'" \
              --username "$POSTGRES_USER" --dbname "$POSTGRES_DB")

if [ -z "$exists" ]; then
    psql_in <<'SQL'
CREATE ROLE :"app_user" LOGIN PASSWORD :'app_password';
SQL
    echo "앱 역할을 만들었다: $APP_DB_USER"
fi

psql_in <<'SQL'
-- ★ 핵심. 이미 있던 역할이 슈퍼유저였더라도 여기서 벗긴다.
ALTER ROLE :"app_user" NOSUPERUSER NOCREATEROLE NOCREATEDB NOBYPASSRLS;

-- Flyway 가 스키마를 만들 수 있어야 한다. 소유자면 CREATE 권한이 따라온다.
ALTER DATABASE :"db_name" OWNER TO :"app_user";
SQL

echo "앱 DB 역할 준비 완료: $APP_DB_USER (NOSUPERUSER, $POSTGRES_DB 소유자)"
