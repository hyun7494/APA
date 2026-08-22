package com.apa.fishing.service;

import com.apa.common.security.AuthenticatedUser;
import com.apa.fishing.domain.FishingPost;
import com.apa.fishing.domain.FishingPostComment;
import com.apa.fishing.domain.FishingPostLike;
import com.apa.fishing.domain.FishingRegion;
import com.apa.fishing.domain.PostCategory;
import com.apa.fishing.dto.CommentCreateRequest;
import com.apa.fishing.dto.CommentResponse;
import com.apa.fishing.dto.LikeResponse;
import com.apa.fishing.dto.PostCreateRequest;
import com.apa.fishing.dto.PostDetailResponse;
import com.apa.fishing.dto.PostResponse;
import com.apa.fishing.repository.FishingPostCommentRepository;
import com.apa.fishing.repository.FishingPostLikeRepository;
import com.apa.fishing.repository.FishingPostRepository;
import com.apa.fishing.repository.FishingRegionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BoardService {

    /** 컬럼이 VARCHAR(100) 다 (V3). 여기가 더 길면 통과시켜 놓고 INSERT 에서 터진다. */
    private static final int TITLE_MAX = 100;

    /** 본문은 text 라 DB 제한은 없지만, 무한정 받으면 목록 응답이 감당이 안 된다. */
    private static final int CONTENT_MAX = 5000;

    /** 댓글 컬럼이 VARCHAR(500) 다 (V9). */
    private static final int COMMENT_MAX = 500;

    private final FishingPostRepository postRepository;
    private final FishingRegionRepository regionRepository;
    private final FishingPostCommentRepository commentRepository;
    private final FishingPostLikeRepository likeRepository;
    private final PhotoStorageService photoStorage;

    // ─────────────────────────────────────────────────────────────── 목록·상세

    /**
     * 목록 조회.
     *
     * <p>tag 가 모르는 값이면 필터를 걸지 않고 전체를 준다 — FREE 로 떨어뜨리면 오타 하나에
     * 엉뚱한 탭 결과가 나간다.
     *
     * @param viewerId 보는 사람. 비로그인이면 null 이고, 그때 {@code likedByMe} 는 전부 false 다
     */
    public List<PostResponse> findPosts(String tag, Long regionGroupId, Long viewerId) {
        PostCategory category = PostCategory.fromCode(tag).orElse(null);
        List<FishingPost> posts = postRepository.findFiltered(category, regionGroupId);

        Set<Long> liked = likedIdsAmong(posts, viewerId);

        return posts.stream()
                .map(post -> PostResponse.from(post, liked.contains(post.getId())))
                .toList();
    }

    public PostDetailResponse findPost(Long id, Long viewerId) {
        FishingPost post = findPostOrThrow(id);
        boolean likedByMe = viewerId != null
                && likeRepository.existsByPostIdAndUserId(id, viewerId);

        return PostDetailResponse.from(post, likedByMe, viewerId);
    }

    /**
     * 목록에 담긴 글 중 내가 좋아요한 것들. <b>질의 한 번</b>이다 —
     * 글마다 물으면 20개 목록에 20번이 된다.
     */
    private Set<Long> likedIdsAmong(List<FishingPost> posts, Long viewerId) {
        if (viewerId == null || posts.isEmpty()) return Set.of();

        List<Long> ids = posts.stream().map(FishingPost::getId).toList();
        return Set.copyOf(likeRepository.findLikedPostIds(viewerId, ids));
    }

    // ─────────────────────────────────────────────────────────────── 글쓰기

    /**
     * 글쓰기 (계약서 3-8).
     *
     * <p>작성자는 <b>토큰에서 온다.</b> 요청 본문으로 받으면 아무나 남의 이름으로 쓸 수 있다.
     */
    @Transactional
    public PostResponse write(AuthenticatedUser user, PostCreateRequest request, MultipartFile photo) {
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
                category, title, content, user.userId(), nicknameOf(user), region,
                storeIfPresent(photo)));

        return PostResponse.from(saved);
    }

    /**
     * 글 고치기. 내 글만.
     *
     * <p><b>없는 글과 남의 글을 구분하지 않고 둘 다 404 다</b> — 403 을 내면 "그 id 는 존재하며
     * 내 것이 아니다"를 알려주는 셈이다 ({@code CatchService} 와 같은 규칙).
     */
    @Transactional
    public PostDetailResponse update(AuthenticatedUser user, Long id,
                                     PostCreateRequest request, MultipartFile photo) {
        FishingPost post = findOwned(user, id);

        String title = required(request.title(), "제목을 입력해 주세요", TITLE_MAX, "제목이 너무 깁니다");
        String content = required(request.content(), "내용을 입력해 주세요", CONTENT_MAX, "내용이 너무 깁니다");
        PostCategory category = PostCategory.fromCode(request.category()).orElse(PostCategory.FREE);

        FishingRegion region = null;
        if (request.regionGroupId() != null) {
            region = regionRepository.findById(request.regionGroupId())
                    .orElseThrow(() -> new ResponseStatusException(
                            HttpStatus.BAD_REQUEST,
                            "지역을 찾을 수 없습니다: " + request.regionGroupId()));
        }

        post.edit(category, title, content, region);

        // 사진 파트를 안 보내면 원래 사진을 그대로 둔다 (CatchService.update 와 같은 규칙) —
        // 글자만 고치려고 사진을 다시 고르게 하면 안 된다.
        String stored = storeIfPresent(photo);
        if (stored != null) {
            deleteIfPresent(post.getPhotoUrl());
            post.attachPhoto(stored);
        }

        boolean likedByMe = likeRepository.existsByPostIdAndUserId(id, user.userId());
        return PostDetailResponse.from(post, likedByMe, user.userId());
    }

    /**
     * 글 지우기. 내 글만.
     *
     * <p>댓글과 좋아요는 <b>DB 가 함께 지운다</b> ({@code ON DELETE CASCADE}, V9).
     * 여기서 하나씩 지우면 새 자식 표가 생길 때마다 빠뜨릴 자리가 늘어난다.
     */
    @Transactional
    public void delete(AuthenticatedUser user, Long id) {
        FishingPost post = findOwned(user, id);
        // 파일은 DB 가 지워 주지 않는다. 행보다 먼저 지워도 되는 이유는, 실패해도
        // 남는 것이 고아 파일 하나뿐이고 글은 정상적으로 사라지기 때문이다.
        deleteIfPresent(post.getPhotoUrl());
        postRepository.delete(post);
    }

    private String storeIfPresent(MultipartFile photo) {
        return (photo == null || photo.isEmpty()) ? null : photoStorage.storeForBoard(photo);
    }

    private void deleteIfPresent(String photoUrl) {
        if (photoUrl != null) {
            photoStorage.delete(photoUrl);
        }
    }

    private FishingPost findOwned(AuthenticatedUser user, Long id) {
        return postRepository.findById(id)
                .filter(post -> post.ownedBy(user.userId()))
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "게시글을 찾을 수 없습니다: " + id));
    }

    // ─────────────────────────────────────────────────────────────── 댓글

    public List<CommentResponse> comments(Long postId, Long viewerId) {
        // 없는 글의 댓글을 빈 목록으로 주면 오타 난 id 가 조용히 지나간다.
        findPostOrThrow(postId);

        return commentRepository.findByPostIdOrderByCreatedAtAsc(postId).stream()
                .map(comment -> CommentResponse.from(comment, viewerId))
                .toList();
    }

    @Transactional
    public CommentResponse addComment(AuthenticatedUser user, Long postId, CommentCreateRequest request) {
        FishingPost post = findPostOrThrow(postId);
        String content = required(request.content(), "댓글을 입력해 주세요", COMMENT_MAX, "댓글이 너무 깁니다");

        FishingPostComment saved = commentRepository.save(
                FishingPostComment.write(postId, user.userId(), nicknameOf(user), content));

        // 세어서 맞춘다. 직접 +1 하면 어딘가에서 한 번 어긋난 뒤로 영영 틀린 채로 간다.
        post.syncCommentCount((int) commentRepository.countByPostId(postId));

        return CommentResponse.from(saved, user.userId());
    }

    /**
     * 내 댓글 삭제.
     *
     * <p><b>없는 댓글과 남의 댓글을 구분하지 않고 둘 다 404 로 낸다.</b> 403 을 내면
     * "그 id 는 존재하며 내 것이 아니다"를 알려주는 셈이다 ({@code CatchService} 와 같은 규칙).
     */
    @Transactional
    public void deleteComment(AuthenticatedUser user, Long commentId) {
        FishingPostComment comment = commentRepository.findById(commentId)
                .filter(c -> c.ownedBy(user.userId()))
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "댓글을 찾을 수 없습니다: " + commentId));

        Long postId = comment.getPostId();
        commentRepository.delete(comment);
        commentRepository.flush();

        postRepository.findById(postId)
                .ifPresent(post -> post.syncCommentCount((int) commentRepository.countByPostId(postId)));
    }

    // ─────────────────────────────────────────────────────────────── 좋아요

    /**
     * 좋아요 토글. 누른 뒤의 상태를 <b>수와 함께</b> 돌려준다.
     *
     * <p>프론트가 자기 쪽에서 +1 하면 그 사이 다른 사람이 누른 것이 빠져 화면과 서버가 어긋난다.
     */
    @Transactional
    public LikeResponse toggleLike(AuthenticatedUser user, Long postId) {
        FishingPost post = findPostOrThrow(postId);
        boolean liked;

        if (likeRepository.existsByPostIdAndUserId(postId, user.userId())) {
            likeRepository.deleteByPostIdAndUserId(postId, user.userId());
            liked = false;
        } else {
            try {
                likeRepository.saveAndFlush(FishingPostLike.of(postId, user.userId()));
            } catch (DataIntegrityViolationException e) {
                // 같은 순간 두 번 눌렸다. PK 가 막아 줬고, 결과(좋아요 상태)는 같으므로
                // 실패로 낼 이유가 없다.
            }
            liked = true;
        }

        likeRepository.flush();
        post.syncLikeCount((int) likeRepository.countByPostId(postId));

        return new LikeResponse(post.getLikeCount(), liked);
    }

    // ─────────────────────────────────────────────────────────────── 공통

    private FishingPost findPostOrThrow(Long id) {
        return postRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "게시글을 찾을 수 없습니다: " + id));
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
