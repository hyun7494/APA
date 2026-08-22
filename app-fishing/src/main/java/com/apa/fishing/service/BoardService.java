package com.apa.fishing.service;

import com.apa.common.security.AuthenticatedUser;
import com.apa.fishing.domain.FishingPost;
import com.apa.fishing.domain.FishingRegion;
import com.apa.fishing.domain.PostCategory;
import com.apa.fishing.dto.PostCreateRequest;
import com.apa.fishing.dto.PostResponse;
import com.apa.fishing.repository.FishingPostRepository;
import com.apa.fishing.repository.FishingRegionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BoardService {

    /** 컬럼이 VARCHAR(255) 다. */
    private static final int TITLE_MAX = 255;

    /** 본문은 text 라 DB 제한은 없지만, 무한정 받으면 목록 응답이 감당이 안 된다. */
    private static final int CONTENT_MAX = 5000;

    private final FishingPostRepository postRepository;
    private final FishingRegionRepository regionRepository;

    /**
     * 목록 조회.
     *
     * <p>tag 가 모르는 값이면 필터를 걸지 않고 전체를 준다 — FREE 로 떨어뜨리면 오타 하나에
     * 엉뚱한 탭 결과가 나간다.
     */
    public List<PostResponse> findPosts(String tag, Long regionGroupId) {
        PostCategory category = PostCategory.fromCode(tag).orElse(null);

        return postRepository.findFiltered(category, regionGroupId).stream()
                .map(PostResponse::from)
                .toList();
    }

    /**
     * 글쓰기 (계약서 3-8).
     *
     * <p>작성자는 <b>토큰에서 온다.</b> 요청 본문으로 받으면 아무나 남의 이름으로 쓸 수 있다.
     */
    @Transactional
    public PostResponse write(AuthenticatedUser user, PostCreateRequest request) {
        String title = required(request.title(), "제목을 입력해 주세요", TITLE_MAX, "제목이 너무 깁니다");
        String content = required(request.content(), "내용을 입력해 주세요", CONTENT_MAX, "내용이 너무 깁니다");

        // 목록 조회와 달리 모르는 코드를 전체로 흘려보낼 수 없다 — 글은 어딘가에 속해야 한다.
        PostCategory category = PostCategory.fromCode(request.category()).orElse(PostCategory.FREE);

        FishingRegion region = null;
        if (request.regionGroupId() != null) {
            region = regionRepository.findById(request.regionGroupId())
                    .orElseThrow(() -> new ResponseStatusException(
                            HttpStatus.BAD_REQUEST,
                            "지역을 찾을 수 없습니다: " + request.regionGroupId()));
        }

        FishingPost saved = postRepository.save(FishingPost.write(
                category, title, content, user.userId(), nicknameOf(user), region));

        return PostResponse.from(saved);
    }

    /**
     * 닉네임이 없는 토큰도 있다 — 카카오에서 프로필 제공에 동의하지 않은 사용자다.
     * 컬럼이 NOT NULL 이라 비워 둘 수 없고, 비워 두면 목록에 작성자가 빈 칸으로 뜬다.
     */
    private String nicknameOf(AuthenticatedUser user) {
        String nickname = user.nickname();
        return nickname == null || nickname.isBlank() ? "익명" : nickname;
    }

    private String required(String value, String blankMessage, int max, String longMessage) {
        if (value == null || value.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, blankMessage);
        }
        String trimmed = value.trim();
        if (trimmed.length() > max) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, longMessage);
        }
        return trimmed;
    }
}
