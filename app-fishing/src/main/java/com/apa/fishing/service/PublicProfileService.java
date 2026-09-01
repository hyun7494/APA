package com.apa.fishing.service;

import com.apa.fishing.domain.FishingPost;
import com.apa.fishing.domain.FishingPostComment;
import com.apa.fishing.dto.PostResponse;
import com.apa.fishing.dto.PublicProfileResponse;
import com.apa.fishing.repository.FishingPostCommentRepository;
import com.apa.fishing.repository.FishingPostRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Stream;

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
        List<FishingPostComment> comments =
                commentRepository.findByUserIdOrderByCreatedAtDesc(userId);

        if (posts.isEmpty() && comments.isEmpty()) {
            // 공개된 활동이 하나도 없다. 계정의 존재 자체를 확인해 주지 않는다 —
            // id 를 훑어 누가 가입했는지 세는 것을 막는다.
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "프로필을 찾을 수 없습니다");
        }

        // ★ 글만 보면 **댓글만 쓴 사람의 프로필이 통째로 404** 가 된다. 댓글 작성자를
        //   눌렀을 때 막다른 길이 되므로 닉네임·시작 시각을 양쪽에서 찾는다.
        String nickname = latestNickname(posts, comments);

        return new PublicProfileResponse(
                userId,
                nickname,
                posts.size(),
                comments.size(),
                postRepository.sumLikesReceived(userId),
                firstActivityAt(posts, comments),
                posts.stream().limit(RECENT_LIMIT).map(PostResponse::from).toList());
    }

    /** 최근에 남긴 쪽의 이름. 닉네임은 안 바뀌지만 둘 중 아무거나 집으면 빈 쪽에서 터진다. */
    private static String latestNickname(List<FishingPost> posts,
                                         List<FishingPostComment> comments) {
        LocalDateTime postAt = posts.isEmpty() ? null : posts.get(0).getCreatedAt();
        LocalDateTime commentAt = comments.isEmpty() ? null : comments.get(0).getCreatedAt();

        if (postAt == null) {
            return comments.get(0).getAuthorNickname();
        }
        if (commentAt == null || postAt.isAfter(commentAt)) {
            return posts.get(0).getAuthorNickname();
        }
        return comments.get(0).getAuthorNickname();
    }

    /** 글이든 댓글이든 **처음 남긴 순간**. "언제부터 활동했나" 가 신뢰의 단서다. */
    private static LocalDateTime firstActivityAt(List<FishingPost> posts,
                                                 List<FishingPostComment> comments) {
        return Stream.concat(
                        posts.stream().map(FishingPost::getCreatedAt),
                        comments.stream().map(FishingPostComment::getCreatedAt))
                .min(Comparator.naturalOrder())
                .orElse(null);
    }
}
