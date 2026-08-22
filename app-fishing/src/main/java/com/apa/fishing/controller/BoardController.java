package com.apa.fishing.controller;

import com.apa.common.security.AuthenticatedUser;
import com.apa.fishing.dto.CommentCreateRequest;
import com.apa.fishing.dto.CommentResponse;
import com.apa.fishing.dto.LikeResponse;
import com.apa.fishing.dto.PostCreateRequest;
import com.apa.fishing.dto.PostDetailResponse;
import com.apa.fishing.dto.PostResponse;
import com.apa.fishing.service.BoardService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 게시판 (계약서 3-6).
 *
 * <p><b>조회는 열려 있고 쓰기만 막혀 있다</b> (기획서 5-5). 목록·상세·댓글 읽기는 비로그인도
 * 되고, 글쓰기·댓글쓰기·좋아요는 SecurityConfig 가 401 로 막는다.
 *
 * <p>읽기 쪽에도 {@code @AuthenticationPrincipal} 을 받는 이유는 <b>{@code likedByMe}</b> 때문이다 —
 * 같은 글이라도 보는 사람에 따라 하트가 눌린 상태인지가 다르다. 비로그인이면 null 로 온다.
 */
@RestController
@RequestMapping("/fishing/board")
@RequiredArgsConstructor
public class BoardController {

    private final BoardService boardService;

    /**
     * regionGroupId 는 계약서에 있지만 프론트가 아직 보내지 않는다 (지역별 필터 UI 미구현).
     * 게시글에 지역이 생겼으므로 서버 쪽은 지금 지원해둔다.
     */
    @GetMapping
    public List<PostResponse> list(@AuthenticationPrincipal AuthenticatedUser user,
                                   @RequestParam(required = false) String tag,
                                   @RequestParam(required = false) Long regionGroupId) {
        return boardService.findPosts(tag, regionGroupId, userId(user));
    }

    /** 글 상세. 목록과 달리 본문 전체를 준다. */
    @GetMapping("/{id}")
    public PostDetailResponse detail(@AuthenticationPrincipal AuthenticatedUser user,
                                     @PathVariable Long id) {
        return boardService.findPost(id, userId(user));
    }

    /**
     * 글쓰기 (계약서 3-8).
     *
     * <p><b>인증 필수다.</b> SecurityConfig 가 {@code POST /fishing/board/**} 를 막고 있어
     * 비로그인은 401 을 받는다 — 목록 조회(GET)는 그대로 공개다 (기획서 5-5).
     *
     * <p>작성자는 요청 본문이 아니라 <b>토큰에서</b> 가져간다. 본문으로 받으면 아무나
     * 남의 이름으로 쓸 수 있다.
     */
    @PostMapping
    public ResponseEntity<PostResponse> write(@AuthenticationPrincipal AuthenticatedUser user,
                                              @RequestBody PostCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(boardService.write(user, request));
    }

    /** 글 수정. 인증 필수이고 <b>남의 글은 404 다</b> (존재 여부를 알려주지 않는다). */
    @PutMapping("/{id}")
    public PostDetailResponse update(@AuthenticationPrincipal AuthenticatedUser user,
                                     @PathVariable Long id,
                                     @RequestBody PostCreateRequest request) {
        return boardService.update(user, id, request);
    }

    /** 글 삭제. 댓글·좋아요는 DB 가 함께 지운다 (V9 의 ON DELETE CASCADE). */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal AuthenticatedUser user,
                                       @PathVariable Long id) {
        boardService.delete(user, id);
        return ResponseEntity.noContent().build();
    }

    /** 댓글 목록. 읽기는 비로그인도 된다. */
    @GetMapping("/{id}/comments")
    public List<CommentResponse> comments(@AuthenticationPrincipal AuthenticatedUser user,
                                          @PathVariable Long id) {
        return boardService.comments(id, userId(user));
    }

    /** 댓글 쓰기. 인증 필수. */
    @PostMapping("/{id}/comments")
    public ResponseEntity<CommentResponse> addComment(@AuthenticationPrincipal AuthenticatedUser user,
                                                      @PathVariable Long id,
                                                      @RequestBody CommentCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(boardService.addComment(user, id, request));
    }

    /**
     * 내 댓글 삭제. 인증 필수이고 <b>남의 댓글은 404 다</b> (존재 여부를 알려주지 않는다).
     *
     * <p>글 id 가 아니라 댓글 id 로 지운다 — 댓글 id 만으로 유일하다.
     */
    @DeleteMapping("/comments/{commentId}")
    public ResponseEntity<Void> deleteComment(@AuthenticationPrincipal AuthenticatedUser user,
                                              @PathVariable Long commentId) {
        boardService.deleteComment(user, commentId);
        return ResponseEntity.noContent().build();
    }

    /**
     * 좋아요 토글. 인증 필수 — 계약서 3-8 대로 POST 다.
     *
     * <p>토글은 멱등이 아니라서 PUT 이 어울리지 않는다. 두 번 부르면 눌렀다 뗀 것이 된다.
     * 덤으로 SecurityConfig 의 {@code POST /fishing/board/**} 규칙이 그대로 덮어 준다.
     */
    @PostMapping("/{id}/like")
    public LikeResponse toggleLike(@AuthenticationPrincipal AuthenticatedUser user,
                                   @PathVariable Long id) {
        return boardService.toggleLike(user, id);
    }

    /** 비로그인이면 principal 자체가 없다. */
    private Long userId(AuthenticatedUser user) {
        return user == null ? null : user.userId();
    }
}
