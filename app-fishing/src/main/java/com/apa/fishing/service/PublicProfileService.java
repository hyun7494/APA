package com.apa.fishing.service;

import com.apa.fishing.domain.FishingPost;
import com.apa.fishing.dto.PostResponse;
import com.apa.fishing.dto.PublicProfileResponse;
import com.apa.fishing.repository.FishingPostCommentRepository;
import com.apa.fishing.repository.FishingPostRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

import java.util.Comparator;
import java.util.List;

/**
 * 공개 프로필. **게시판 활동만** 모은다 ({@link PublicProfileResponse} 참고).
 *
 * <p>auth-service 를 부르지 않는다 — 닉네임까지 글 행에 있어서 이 서비스 안에서 끝난다.
 * 동호회 탭을 붙일 때도 이 경계가 유지된다.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PublicProfileService {

    /** 프로필에 실어 보내는 글 수. 더 보려면 게시판에서 본다 — 여기는 맛보기다. */
    private static final int RECENT_LIMIT = 20;

    private final FishingPostRepository postRepository;
    private final FishingPostCommentRepository commentRepository;

    public PublicProfileResponse of(Long userId) {
        List<FishingPost> posts = postRepository.findByAuthor(userId);
        if (posts.isEmpty()) {
            // 글이 하나도 없으면 보여 줄 공개 활동이 없다. 계정의 존재 자체를 확인해
            // 주지 않는 편이 낫다 — id 를 훑어 누가 가입했는지 세는 것을 막는다.
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "프로필을 찾을 수 없습니다");
        }

        List<PostResponse> recent = posts.stream()
                .limit(RECENT_LIMIT)
                .map(PostResponse::from)
                .toList();

        return new PublicProfileResponse(
                userId,
                posts.get(0).getAuthorNickname(),
                posts.size(),
                commentRepository.countByUserId(userId),
                postRepository.sumLikesReceived(userId),
                posts.stream()
                        .map(FishingPost::getCreatedAt)
                        .min(Comparator.naturalOrder())
                        .orElse(null),
                recent);
    }
}
