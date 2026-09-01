-- 운세를 걷어낸다.
--
-- Rev 2 가 프론트에서 운세를 빼면서 "백엔드 스키마와 배치는 유지" 로 남겨 뒀는데,
-- 그 결과가 **아무도 안 읽는 행을 매일 쌓는 배치**였다 — FortuneScheduler 가 00:10 마다
-- 12간지 × 하루치를 넣어 48행이 쌓여 있었고, 읽는 쪽(FortuneController)은 프론트가
-- 한 번도 부르지 않았다. 코드 아홉 파일과 표 둘을 함께 지운다 (2026-09-01 결정).
--
-- ★ 되살릴 때는 이 마이그레이션의 커밋에서 지워진 코드를 그대로 꺼내면 된다 —
--   기획서 Rev 1 의 2-2(오늘의 운세)·3-4(Fortune) 가 사양이고,
--   README 의 "나중에 붙일 것" 에 좌표를 적어 뒀다.
--
-- fishing_user_zodiac 은 행이 0 이다. fishing_daily_fortune 의 48행은 배치가 만든
-- 것으로 사용자 데이터가 아니라서 그냥 버린다.

DROP TABLE fishing_user_zodiac;
DROP TABLE fishing_daily_fortune;
