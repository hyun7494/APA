package com.apa.fishing.service;

import com.apa.fishing.domain.PostCategory;
import com.apa.fishing.dto.PostResponse;
import com.apa.fishing.repository.FishingPostRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BoardService {

    private final FishingPostRepository postRepository;

    /**
     * 목록 조회. 프론트가 지금 호출하는 건 이것 하나뿐이다 (글쓰기·좋아요·신고는 UI가 아직 없다).
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
}
