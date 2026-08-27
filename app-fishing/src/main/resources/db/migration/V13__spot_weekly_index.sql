-- 주간 낚시지수.
--
-- ★ 새 데이터 소스가 아니다. **이미 받고 있던 응답의 나머지 날짜를 버리지 않는 것뿐**이다.
--
-- KHOA 바다낚시지수는 `reqDate` 를 오늘로 주면 **한 번 호출에 오늘 + 6일 = 7일치**를 준다
-- (2026-08-27 실측: 60행 / 7일). 그런데 `FishingIndexParser` 가 `predcYmd` 가 오늘인 행만
-- 남기고 나머지 엿새를 버려 왔다. 호출 횟수를 늘리지 않고 화면에 일주일을 깔 수 있다.
--
-- ⚠️ 하루 한 행이다. 원본은 (날짜 × 오전/오후 × 어종)으로 오는데, **오전/오후 구분은 앞
--    사흘까지만** 있고 D+3 부터는 `predcNoonSeCd = '일'` 로 하루 단위다 (같은 실측).
--    시간대별로 쪼개 두면 뒤쪽 나흘이 빈 칸이 되므로 여기서는 하루로 접는다.
--    오전/오후를 화면에 쓰게 되면 그때 열 하나를 더할 것.

CREATE TABLE fishing_spot_daily_index (
    spot_id       BIGINT NOT NULL REFERENCES fishing_spots(id) ON DELETE CASCADE,
    forecast_date DATE   NOT NULL,

    -- 그날 어종별 지수 중 **가장 좋은** 값. 한 어종이라도 잘 물면 갈 만한 곳이라는
    -- 기존 규칙(KhoaFishingIndex.rating)을 그대로 쓴다.
    rating        VARCHAR(20) NOT NULL,

    -- 안전 관련 수치는 **하루 최악값**이다. 평균을 쓰면 "오전엔 잔잔한데 오후에 3m"인 날이
    -- 좋은 날로 보인다 (KmaForecast 주석과 같은 이유).
    wave_height   NUMERIC(4,1),
    wind_speed    NUMERIC(4,1),
    water_temp    NUMERIC(4,1),

    updated_at    TIMESTAMP NOT NULL DEFAULT now(),

    -- 같은 날짜를 두 번 넣지 않는다. 배치가 매일 도는데 예보 창이 겹치므로
    -- 덮어쓰기(upsert)가 기본 동작이 되어야 한다.
    PRIMARY KEY (spot_id, forecast_date)
);

-- 한 포인트의 일주일을 날짜순으로 읽는다. 화면이 늘 이 순서로 쓴다.
CREATE INDEX idx_spot_daily_index_date ON fishing_spot_daily_index(spot_id, forecast_date);
