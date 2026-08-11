-- 시안 게시글 4건. 원본: fishing_app/lib/data/mock_data.dart 의 posts
-- (지금까지 BoardService 가 하드코딩하던 값과 같다 — 이 마이그레이션으로 DB 로 옮긴다)
--
-- created_at 을 상대 시각으로 넣는 이유: 프론트가 "2시간 전" / "어제" 로 렌더하기 때문에
-- 고정 날짜를 넣으면 시간이 지날수록 전부 "n일 전"이 되어 시안과 달라 보인다.

INSERT INTO fishing_posts
    (id, category, title, content, author_nickname, region_group_id,
     like_count, comment_count, has_image, created_at)
VALUES
    (1, 'CATCH', '오늘 학리에서 감성돔 4짜 손맛!',
     '새벽 물때에 입질 폭발했습니다. 다들 출조하세요~',
     '바다사나이', 1, 24, 8, true,  now() - interval '2 hours'),

    (2, 'CATCH', '참돔 시즌 시작! 새벽 물때 강추',
     '사량도 옥동 갯바위 자리 좋습니다. 채비는 가볍게.',
     '갯바위킹', 4, 41, 15, true,  now() - interval '1 day'),

    (3, 'FREE', '초보도 잡았네요 ㅎㅎ 볼락 조황 좋아요',
     '잔잔하고 수온 안정적이라 가족이랑 다녀왔어요.',
     '손맛중독', 3, 12, 3, false, now() - interval '5 hours'),

    (4, 'QUESTION', '영종도 우럭 포인트 추천 부탁드려요',
     '주말에 처음 가보는데 선착장 근처 어떤가요?',
     '릴사랑', 2, 5, 9, false, now() - interval '1 day');

-- id 를 직접 넣었으므로 시퀀스를 밀어준다. 빼먹으면 첫 글쓰기가 id=1 로 시도해 중복 키 에러가 난다.
SELECT setval('fishing_posts_id_seq', (SELECT MAX(id) FROM fishing_posts));
