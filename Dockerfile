# 두 서비스가 같은 이미지를 쓴다 — 빌드가 그레이들 멀티모듈 하나이고,
# 다른 것은 어느 jar 를 실행하느냐뿐이다. compose 가 SERVICE 인자로 고른다.

# ── 빌드 ────────────────────────────────────────────────────────────────
FROM gradle:8.11-jdk21 AS build
WORKDIR /src

# 의존성 먼저 받아 캐시에 남긴다. 소스만 고쳤을 때 이 층을 다시 받지 않는다.
COPY settings.gradle build.gradle ./
COPY common-lib/build.gradle    common-lib/
COPY auth-service/build.gradle  auth-service/
COPY app-fishing/build.gradle   app-fishing/
RUN gradle --no-daemon dependencies --refresh-dependencies || true

COPY common-lib   common-lib
COPY auth-service auth-service
COPY app-fishing  app-fishing
RUN gradle --no-daemon :auth-service:bootJar :app-fishing:bootJar -x test

# ── 실행 ────────────────────────────────────────────────────────────────
FROM eclipse-temurin:21-jre
WORKDIR /app

# ⚠️ 이 이미지에 curl 이 없다. compose 의 헬스체크가 그걸 부르므로 넣어 준다 —
#    없으면 헬스체크가 **영원히 unhealthy** 라 depends_on 이 안 풀린다.
RUN apt-get update  && apt-get install -y --no-install-recommends curl  && rm -rf /var/lib/apt/lists/*

# ★ 시간대를 박는다. 컨테이너 기본은 UTC 라 그대로 두면 글·조과의 작성 시각이
#   아홉 시간 밀린다. 코드도 `Kst` 로 시간대를 명시하므로 **둘 중 하나만 통해도**
#   값은 맞는다 — 일부러 겹쳐 둔 방어다.
ENV TZ=Asia/Seoul
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# root 로 돌리지 않는다. 사진 볼륨도 이 사용자가 쓴다.
RUN useradd --create-home --shell /bin/bash apa

# ★ 사진 디렉터리를 **이미지 안에 미리 만들고 소유권을 넘긴다.**
#   도커는 빈 경로에 이름 있는 볼륨을 붙일 때 **이미지 쪽 디렉터리의 소유권을 복사**한다.
#   이게 없으면 볼륨이 root 소유로 생기고, 비-root 로 도는 이 프로세스는 거기 못 쓴다 —
#   증상은 사진 업로드가 500 이고 로그에는 톰캣 스택만 남아 원인이 잘 안 보인다.
#   ⚠️ `USER apa` 보다 **위**여야 한다. 아래로 내리면 chown 권한이 없다.
RUN mkdir -p /var/lib/apa/photos && chown -R apa:apa /var/lib/apa
# ⚠️ `*.jar` 로 받으면 안 된다 — 그레이들이 실행 가능한 jar 와 `-plain.jar` 를 **둘 다**
#    만들어서 와일드카드가 두 개를 집는다. 이름을 정확히 준다
#    (plain jar 는 build.gradle 에서 꺼 뒀지만, 여기서도 못박아 둔다).
COPY --from=build /src/auth-service/build/libs/auth-service.jar auth-service.jar
COPY --from=build /src/app-fishing/build/libs/app-fishing.jar   app-fishing.jar
RUN chown -R apa:apa /app
USER apa

# compose 가 넘긴다: auth-service | app-fishing
ENV SERVICE=app-fishing
ENTRYPOINT ["sh", "-c", "exec java -Duser.timezone=Asia/Seoul -jar /app/${SERVICE}.jar"]
