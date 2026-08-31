-- 닉네임을 유일하게 만든다.
--
-- 지금까지 **제약도 검사도 없었다.** 이메일만 UNIQUE 였고 닉네임은 그냥 저장했다.
-- 게시판이 있는 앱이라 글쓴 사람을 구별할 수 있어야 하고, 신고·차단도 그 전제에서만
-- 뜻이 생긴다. 같은 이름 둘을 허용하면 사칭이 기능이 된다.
--
-- ★ `lower(nickname)` 위에 건다. 그냥 UNIQUE(nickname) 이면 `Bada` 와 `bada` 가
--   서로 다른 이름이 되어, 눈으로 구별 안 되는 계정 둘이 생긴다.
--   앞뒤·가운데 공백은 애플리케이션(`Nickname.normalize`)이 정리해서 넣는다.
--
-- ⚠️ 이미 중복이 있으면 이 마이그레이션이 **실패한다.** 그게 맞다 — 조용히 한쪽을
--    고쳐 주면 어느 계정의 이름이 바뀌었는지 아무도 모른다. 실패하면 아래로 찾아
--    사람이 판단해서 정리한 뒤 다시 올릴 것:
--
--      SELECT lower(nickname), count(*), array_agg(id)
--      FROM users GROUP BY lower(nickname) HAVING count(*) > 1;

CREATE UNIQUE INDEX uq_users_nickname_lower ON users (lower(nickname));
