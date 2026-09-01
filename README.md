# APA

여러 앱이 **계정 하나(APA 통합 계정)** 를 공유하는 모노레포. 첫 앱은 낚시출조앱이다 —
낚시 지수 조회 · 어류 도감 · 조과 기록 · 게시판.

```
APA/
├── common-lib/        JWT 검증 등 백엔드 공통 코드 (스프링 모듈)
├── auth-service/      계정 서비스        :8081  (스프링 부트)
├── app-fishing/       낚시 앱 서비스     :8086  (스프링 부트)
├── fishing_app/       낚시 앱 프론트           (Flutter)
├── gradle/ gradlew    그레이들 래퍼
├── settings.gradle    백엔드 모듈 구성 (common-lib · auth-service · app-fishing)
└── .github/           이슈·PR 템플릿
```

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
└── config/          기능 플래그
design/              Deep Tide 시안 (.dc.html) — 화면 주석이 이 파일들을 참조한다
test/                위젯 테스트. 저장소를 대역으로 갈아끼워 화면 흐름을 잡는다
```

⚠️ 위젯 테스트는 대역을 쓰므로 **플랫폼 SDK 를 타는 흐름(로그인·로그아웃·보안 저장소)은
브라우저에서 눈으로 봐야 한다.** 실제로 웹 로그아웃이 멈추는 버그를 테스트가 못 잡았다.

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

## 문서

기획서·API 계약서·진행상황·세션 인계 md 는 **저장소 밖** (`../` 상위 폴더)에 있다.
API 규격의 정본은 `낚시출조앱_API계약서.md`, 작업 내역과 판단 근거는
`낚시출조앱_진행상황.md` 다. 계약이 바뀌면 계약서를 함께 고친다.
