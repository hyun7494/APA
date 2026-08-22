-- 게시글 사진.
--
-- V3 는 fishing_posts 에 has_image 를 두었지만 **사진을 담을 자리가 없었다** — V4 시드가
-- true 를 박아 넣어서 카드에 카메라 아이콘이 뜨는데 열어 볼 것이 없었다.
-- V9 의 like_count·comment_count 와 같은 꼴이다.

ALTER TABLE fishing_posts ADD COLUMN photo_url VARCHAR(255);

-- 시드가 박아 둔 has_image=true 를 되돌린다. 사진이 실제로 없다.
-- 이제 이 값은 photo_url 이 있느냐로만 정해진다.
UPDATE fishing_posts SET has_image = false WHERE photo_url IS NULL;
