# APA

여러 앱이 **계정 하나(APA 통합 계정)** 를 공유하는 모노레포. 첫 앱은 낚시출조앱이다 —
낚시 지수 조회 · 어류 도감 · 조과 기록 · 게시판.

```
APA/
├── common-lib/        JWT 검증 등 백엔드 공통 코드 (스프링 모듈)
├── auth-service/      계정 서비스        :8081  (스프링 부트)
├── app-fishing/       낚시 앱 서비스     :8086  (스프링 부트)
├── fishing_app/       낚시 앱 프론트           (Flutter)
├── Dockerfile         두 서비스가 함께 쓰는 이미지 (SERVICE 로 고른다)
├── docker-compose.yml postgres + 두 서비스 + 사진 볼륨
├── gradle/ gradlew    그레이들 래퍼
├── settings.gradle    백엔드 모듈 구성 (common-lib · auth-service · app-fishing)
└── .github/           이슈·PR 템플릿
```

### 이름 규칙

- 테이블은 스키마 안에서도 서비스 접두사를 붙인다 — `fishing.fishing_posts`.
  스키마가 이미 이름을 나누지만, 스키마 없이 테이블명만 보는 자리(로그·백업·모니터링)
  에서도 어느 서비스 것인지 읽히게 **일부러** 겹쳐 둔다 (2026-09-01 결정)
- `fishing_regions` 의 행은 권역(동해·서해·남해·제주)이고 참조 컬럼은
  `region_group_id` 다. V14 가 시·군 지역을 권역으로 재편하면서 남은 어긋남인데,
  `regionGroupId` 가 API 계약(3-1)에 굳어 있어 **그대로 둔다** — 고치는 값보다
  계약을 깨는 값이 크다

DB 는 Postgres 하나(`apa`)를 쓰되 **서비스마다 스키마를 나눈다** — `auth` 와 `fishing`.
마이그레이션은 서비스별 Flyway 가 각자 관리한다 (`src/main/resources/db/migration`).

## 서비스 경계 — 이 저장소의 제 1 원칙

**앱 서비스는 auth-service 를 호출하지 않고, auth-service 는 앱 서비스를 모른다.**

- 요청 사용자는 JWT 로 안다. 토큰 subject 가 `userId`, claim 에 `nickname` 이 실려 있어
  앱 서비스가 auth 를 다시 부를 필요가 없다 (`common-lib` 의 `AuthenticatedUser`)
- `fishing` 스키마의 `user_id` 컬럼들은 `auth.users` 를 **참조하지만 FK 를 걸지 않는다**
- 두 서비스에 걸치는 작업(예: 회원 탈퇴)은 **프론트가 조율한다** —
  `DELETE /fishing/me` → `DELETE /auth/me` 순서로 각각 부른다
- 게시글의 작성자 이름은 작성 시점 닉네임을 행에 박아 둔다(스냅샷). 닉네임이
  유일하고(`lower(nickname)` UNIQUE) 탈퇴해도 이름을 회수하지 않으므로
  스냅샷이 어긋날 일이 없다

## auth-service (:8081)

APA 공통 계정. 이메일/비밀번호 가입 + 소셜(카카오·구글) 로그인 + 계정 연동.

```
com.apa.auth/
├── controller/   /auth/*  (signup · login · login/email · link/social · refresh · logout · me)
├── service/      AuthService(가입·로그인·탈퇴) · ConsentRecorder(약관 동의)
│                 Nickname · EmailAddress · PasswordPolicy (값 정규화 — 저장·조회 양쪽에서 통과)
├── social/       카카오·구글 토큰 검증
├── domain/       User · UserConsent · RefreshToken · UserAppLink · UserSocialAccount
└── db/migration/ V1 ~  (users · refresh_tokens · user_app_links · user_social_accounts
                         · user_consents · user_fcm_tokens)
```

- 탈퇴는 소프트 삭제다 — 행을 남겨야 닉네임이 영구히 잠기고 `user_id` 참조가 살아 있다
- `user_consents` 는 덧붙이기만 한다(append-only). 철회 이력이 남는 게 존재 이유다

## app-fishing (:8086)

낚시 도메인 전부 — 지수 · 도감 · 조과 · 게시판 · 사진.

```
com.apa.fishing/
├── controller/   /fishing/*  (regions · spots · board · me/catches · me/collection · me/photos …)
├── service/      SpotService(지수·검색·대표) · BoardService · CatchService · WithdrawalService …
├── batch/        공공 API 배치 — 매일 05:20 51개 포인트 갱신
│   ├── khoa/     국립해양조사원 바다낚시지수 (등급·수온·물때·주간)
│   ├── kma/      기상청 단기예보 (날씨·풍속·파고·시간대별 그래프)
│   └──           GridConverter · Haversine · SolarTime · RatingRule · HourlyScore
│                 — 전부 키 없이 도는 순수 함수라 단위 테스트로 잡는다
├── domain/       FishingSpot · FishingPost · CatchRecord · Species …
└── db/migration/ V1 ~  (fishing_spots · fishing_regions · fishing_posts · fishing_species
                         · fishing_user_catches · fishing_spot_daily_index …)
```

- 배치가 받아 온 값만 신뢰한다. **null 은 "값 없음"이고 0 이 아니다** — 없는 값을
  0 이나 기본값으로 메우지 않고, 프론트는 그때 해당 칸·카드를 감춘다
- 사진은 로컬 볼륨(`fishing.photo.dir`, 기본 `data/photos/`)에 저장하고 저장소에 안 넣는다
- ★ **사진은 공개 범위별로 폴더가 갈린다** (`photos/catch/`·`photos/board/`, `PhotoScope`).
  조과 인증샷은 본인만, 게시글 사진은 누구나 본다. 예전엔 한 폴더에 두고 URL 앞부분으로만
  갈랐는데, **인증 없는 게시판 경로로 남의 인증샷을 그대로 받아 갈 수 있었다.**
  공개 서빙 경로를 새로 만들 때는 반드시 범위를 못박을 것

## fishing_app (Flutter)

```
lib/
├── main.dart        진입 — 테마 로드 후 runApp
├── router/          GoRouter. 하단 탭 5개(지수·도감·홈·게시판·마이)가 각자 스택을 가진다
├── screens/         화면 17개 (홈 · 지수 목록/상세 · 지역 검색 · 도감 · 어종 상세 · 기록 추가
│                    · 획득 연출 · 게시판 · 글 상세/쓰기 · 마이 · 설정 · 고객센터 · 약관 · 로그인 · 가입)
├── widgets/         공용 위젯 (카드 · 칩 · 배지 · 주간 지수 스트립 · 신고 시트 …)
├── services/        저장소 계층. FishingRepository 인터페이스에 Mock/Remote 두 구현 —
│                    `--dart-define=USE_MOCK=false` 로 실서버 전환. AuthRepository 도 같은 구조
├── models/          API 응답 모델 (barrel: models.dart)
├── theme/           팔레트·타이포·아이콘 (barrel: app_theme.dart). 라이트/다크 런타임 전환
├── data/            시드·목 데이터 · 약관 본문(legal_documents.dart)
design/              Deep Tide 시안 (.dc.html) — 화면 주석이 이 파일들을 참조한다
test/                위젯 테스트. 저장소를 대역으로 갈아끼워 화면 흐름을 잡는다
```

⚠️ 위젯 테스트는 대역을 쓰므로 **플랫폼 SDK 를 타는 흐름(로그인·로그아웃·보안 저장소)은
브라우저에서 눈으로 봐야 한다.** 실제로 웹 로그아웃이 멈추는 버그를 테스트가 못 잡았다.

## 시간대 — 이 저장소의 두 번째 원칙

**맨 `LocalDateTime.now()` 를 쓰지 말 것.** `common-lib` 의 `Kst.now()`·`Kst.today()` 를 쓴다.

맨 `now()` 는 JVM 기본 시간대를 따르는데 **컨테이너는 기본이 UTC** 다. 개발 노트북에서는
KST 라 맞아 보이지만 그대로 올리면 글·조과의 작성 시각과 토큰 만료가 아홉 시간 밀린다.
더 나쁜 건 배치(KST 명시)와 글(UTC)이 **한 DB 안에서 갈라진다**는 것이다 — 컬럼이 전부
`timestamp without time zone` 이라 나중에 어느 쪽인지 알 방법도 없다.

컨테이너에도 `TZ=Asia/Seoul` 을 준다. 그건 **덤**이다 — 환경변수를 빠뜨려도 코드만 통하면
값은 맞는다. 나라가 늘면 그때는 컬럼을 `timestamptz` 로 옮기는 것이 먼저다.

## 설정 — 전부 환경변수

| | 기본값 | 배포에서 |
|---|---|---|
| `JWT_SECRET` | **없음 (부팅 실패)** | 32바이트 이상. **두 서비스가 같은 값** |
| `WITHDRAWN_SECRET` | **없음 (부팅 실패)** | 16자 이상. 탈퇴자 꼬리표 해시의 소금. **한 번 정하면 바꾸지 말 것** — 바꾸면 이미 가려진 글의 꼬리표가 전부 달라진다 |
| `DB_HOST`·`DB_PORT`·`DB_NAME`·`DB_USER` | localhost:5432/apa/apa_user | 도커는 `postgres` |
| `DB_PASSWORD` | 없음 | 필수 |
| `AUTH_DEV_LOGIN` | **false** | 켜면 누구나 userId=1 토큰을 받아간다 |
| `CORS_ALLOWED_ORIGINS` | `localhost:*` | **실제 도메인만** |
| `PHOTO_DIR` | `data/photos` | 볼륨 경로 |
| `KMA_SERVICE_KEY`·`KHOA_SERVICE_KEY` | 없음 | 없으면 지수 배치만 건너뛴다 |

## 실행

```bash
# 백엔드 (비밀값은 저장소 밖 apa-secrets.env)
./gradlew :auth-service:bootRun
./gradlew :app-fishing:bootRun     # 부팅 직후 지수 배치가 돈다 (~60초)

# 프론트 — 목 데이터로 (서버 불필요)
cd fishing_app && flutter run

# 프론트 — 실서버로 (⚠️ AUTH_BASE_URL 빠뜨리면 로그인만 조용히 죽는다)
flutter run --dart-define=USE_MOCK=false \
  --dart-define=API_BASE_URL=http://localhost:8086 \
  --dart-define=AUTH_BASE_URL=http://localhost:8081

# 검사
./gradlew :app-fishing:test :auth-service:test
cd fishing_app && flutter analyze && flutter test
```

### 도커로 한 번에

```bash
docker compose --env-file ../apa-secrets.env up -d --build
docker compose ps          # 셋 다 healthy 가 될 때까지 기다린다
docker compose logs -f app-fishing
```

⚠️ **사진 볼륨(`photos`)을 지우지 말 것.** `docker compose down` 은 볼륨을 남기지만
`down -v` 는 지운다 — 그러면 사용자 도감의 표지 사진이 통째로 사라진다.

⚠️ app-fishing 은 부팅 직후 지수 배치(51곳 × 공공 API, 약 60초)를 돈다. 그동안
healthy 로 안 바뀌므로 `start_period` 를 120초로 잡아 뒀다.

## 보안에서 지키는 것

한 번씩 실제로 뚫렸던 자리다. 고칠 때 이 근거를 먼저 볼 것.

- **사진의 경계는 폴더다** — 위 app-fishing 절 참고. 확인 코드 한 줄이 아니라 폴더로 가른
  이유는, 공개 서빙 경로가 하나 더 생겨도 같은 구멍이 다시 열리지 않게 하기 위해서다
- **비밀값에 기본값을 두지 않는다** — `JWT_SECRET`·`WITHDRAWN_SECRET` 둘 다 없으면 부팅이
  실패한다. 공개 저장소라 소스에 박힌 기본값은 곧 공개된 값이고, 실제로 탈퇴자 꼬리표를
  내부 `user_id` 로 되짚을 수 있었다
- **로그인은 계정과 출발지를 함께 센다** (`LoginAttemptGuard`). 출발지 한도가 계정 한도보다
  훨씬 넉넉한 이유는, 같으면 **공유 IP 뒤의 애먼 사람들이 같이 막히기** 때문이다.
  ⚠️ 메모리에 세므로 인스턴스가 하나일 때만 온전하다 — 늘릴 때 함께 옮길 것
- **비밀번호는 구성 규칙 대신 흔한 것을 막는다** — 대문자·특수문자를 강제하면 `Password1!`
  로 몰릴 뿐이고 `12345678` 은 그대로 통과한다 (NIST SP 800-63B)
- **X-Forwarded-For 를 믿지 않는다** — 헤더라 아무나 적어 보낸다. 리버스 프록시를 앞에 둘
  때 `server.forward-headers-strategy` 로 신뢰 경계를 명시할 것

## 나중에 붙일 것

- **오늘의 운세** — Rev 2 에서 프론트를 안 만들었고, 남겨 둔 백엔드(배치·표·API)마저
  아무도 안 읽는 행만 매일 쌓아서 2026-09-01 에 **통째로 걷어냈다** (`V17`).
  되살릴 때: 사양은 기획서 **Rev 1 의 2-2·3-4**, 코드는 V17 커밋에서 지워진
  아홉 파일을 git 히스토리에서 꺼내면 된다 (`git log --diff-filter=D -- '*Fortune*'`)
- **소셜 로그인 실연동** — 카카오·구글 키 발급이 먼저다. ⚠️ 소셜은 첫 로그인이 곧
  가입이라 **약관 동의를 그 화면에서 함께 받아야 한다**
- **푸시 알림** — `user_fcm_tokens` 표만 있다. FCM 을 붙일 때 마이 메뉴의
  `알림 설정` 을 되살릴 것
- **동호회 탭 · 프로필(갤로그)** — 경계를 안 넘고 만들 수 있다. 구조 노트는
  진행상황 md 7장 참고

## 문서

기획서·API 계약서·진행상황·세션 인계 md 는 **저장소 밖** (`../` 상위 폴더)에 있다.
API 규격의 정본은 `낚시출조앱_API계약서.md`, 작업 내역과 판단 근거는
`낚시출조앱_진행상황.md` 다. 계약이 바뀌면 계약서를 함께 고친다.
