-- KHOA 바다낚시지수 조회 키. khoa_obs_code 를 대체한다.
--
-- ⚠️ 이름을 바꾼 이유: 조회 파라미터(placeName)는 관측소 코드가 아니라 **해역명**이다.
--    'obs_code' 라는 이름 때문에 관측소 코드를 찾아 넣으려다 시간을 날리기 딱 좋다.
--
-- ★ KHOA 의 seafsPstnNm 은 낚시 포인트가 아니라 **전국 49곳짜리 광역 해역**이다.
--   '기장 학리' 같은 포인트명은 존재하지 않는다. 그래서 이름이 아니라 **좌표 거리**로 붙였다
--   (2026-08-13 전수 조회, 낚시출조앱_KHOA장소조회.ps1 로 재현 가능).
--
--   id  포인트              해역          거리     어종 수
--   1   기장 학리           부산동부       6.2km    6
--   2   기장 대변항 방파제   부산동부       3.7km    6
--   3   영종도 선착장       (없음)         -        -     ← 아래 참고
--   4   돌산 갯바위         연도          28.2km    7
--   5   사량도 옥동         욕지도        25.4km    5
--   6   구룡포 방파제       포항          17.4km    5
--
-- ⚠️ 1번과 2번은 같은 해역이라 등급·수온이 항상 같아진다. 실제로 2.5km 떨어진 같은 바다라
--    데이터를 사실대로 보여주는 쪽을 택했다. 시안에서 두 값이 달라 보이던 것과는 다르다.
--
-- ⚠️ 3번 영종도는 일부러 NULL 이다. 가장 가까운 게 '인천항 서측(24km)' 인데 19.7km 밖
--    먼바다이고 어종 구분 없이 '-' 하나만 준다. NULL 이면 배치가 기상청 + RatingRule 폴백으로
--    등급을 낸다. 값이 없는 게 아니라 **다른 경로로 채운다**는 뜻이므로 지우거나 채우지 말 것.

ALTER TABLE fishing_spots ADD COLUMN khoa_place_name VARCHAR(40);

UPDATE fishing_spots SET khoa_place_name = '부산동부' WHERE id = 1;
UPDATE fishing_spots SET khoa_place_name = '부산동부' WHERE id = 2;
-- id = 3 (영종도 선착장) 은 NULL 유지 — RatingRule 폴백
UPDATE fishing_spots SET khoa_place_name = '연도'     WHERE id = 4;
UPDATE fishing_spots SET khoa_place_name = '욕지도'   WHERE id = 5;
UPDATE fishing_spots SET khoa_place_name = '포항'     WHERE id = 6;

ALTER TABLE fishing_spots DROP COLUMN khoa_obs_code;
