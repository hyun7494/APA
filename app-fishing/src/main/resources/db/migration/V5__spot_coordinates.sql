-- 포인트별 좌표와 기상청 격자. Step 6(공공 API 배치)이 이 값을 보고 예보를 조회한다.
--
-- grid_nx / grid_ny 는 GridConverter(위경도 → 기상청 격자, Lambert Conformal Conic)로
-- 계산한 값을 넣은 것이다. 포인트가 6개뿐이라 런타임 변환 대신 저장해 둔다.
-- 포인트를 추가할 때도 같은 클래스로 계산해서 넣으면 된다.
--
-- ⚠️ 위경도는 각 포인트의 대표 지점 근사값이다. 격자가 5km 단위라 수백 m 오차는
--    같은 칸에 들어가지만, 실제 출조 지점과 다르면 여기부터 확인할 것.
--
-- ⚠️ khoa_obs_code(국립해양조사원 관측소 코드)는 아직 NULL 이다.
--    수온·물때가 여기서 오는데, 포인트마다 어느 관측소를 붙일지는 실제 관측소 목록을
--    보고 정해야 한다. 추측해서 넣으면 엉뚱한 지역의 수온이 화면에 뜬다.

UPDATE fishing_spots SET latitude = 35.240900, longitude = 129.226000, grid_nx = 100, grid_ny = 77  WHERE id = 1;  -- 기장 학리
UPDATE fishing_spots SET latitude = 35.218100, longitude = 129.223300, grid_nx = 100, grid_ny = 77  WHERE id = 2;  -- 기장 대변항 방파제
UPDATE fishing_spots SET latitude = 37.491300, longitude = 126.522000, grid_nx = 52,  grid_ny = 125 WHERE id = 3;  -- 영종도 선착장
UPDATE fishing_spots SET latitude = 34.665000, longitude = 127.760000, grid_nx = 75,  grid_ny = 64  WHERE id = 4;  -- 돌산 갯바위
UPDATE fishing_spots SET latitude = 34.848000, longitude = 128.224000, grid_nx = 83,  grid_ny = 68  WHERE id = 5;  -- 사량도 옥동
UPDATE fishing_spots SET latitude = 35.990000, longitude = 129.553000, grid_nx = 106, grid_ny = 94  WHERE id = 6;  -- 구룡포 방파제
