package com.apa.fishing.service;

import com.apa.fishing.domain.CatchRecord;
import com.apa.fishing.repository.CatchRecordRepository;
import com.apa.fishing.repository.FishingPostCommentRepository;
import com.apa.fishing.repository.FishingPostLikeRepository;
import com.apa.fishing.repository.FishingPostRepository;
import com.apa.fishing.repository.FishingUserFavoriteRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * 탈퇴할 때 이 서비스가 가진 흔적을 정리한다.
 *
 * <p>★ <b>auth-service 가 이걸 부르지 않는다.</b> 앱이 두 서비스에 차례로 요청한다 —
 * 여기가 먼저, 계정 비활성이 나중이다. 이유가 둘이다:
 *
 * <ol>
 *   <li>서비스 사이에 새 의존을 만들지 않는다. auth 가 fishing 을 알게 되면 앱이 늘 때마다
 *       auth 가 그 앱들을 다 알아야 한다 (FK 를 안 건 것과 같은 이유)</li>
 *   <li><b>순서를 뒤집으면 못 지운다.</b> 계정을 먼저 비활성하면 토큰이 죽어서 이 요청을
 *       보낼 수 없다</li>
 * </ol>
 *
 * <p>⚠️ 그래서 <b>여기는 성공했는데 계정 비활성이 실패하는 창</b>이 있다. 그때는 데이터만
 * 지워지고 계정은 살아 있다 — 다시 탈퇴를 누르면 된다(이 작업은 여러 번 돌려도 같다).
 * 반대 순서였다면 계정만 죽고 데이터가 영영 남는다.
 *
 * <p><b>무엇을 지우고 무엇을 남기는지</b>는 이용약관·개인정보 처리방침과 맞춰 둔 것이다:
 * <ul>
 *   <li>조과 기록·인증샷 — <b>지운다.</b> 본인만 보는 개인 기록이다</li>
 *   <li>게시글·댓글 — <b>남기고 이름만 가린다.</b> 약관 12조 3항이 그렇게 알린다.
 *       지우면 남들이 나눈 대화에 구멍이 생긴다</li>
 *   <li>좋아요·즐겨찾기 — 지운다. 집계에만 쓰이고 이름이 안 붙는다</li>
 * </ul>
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class WithdrawalService {

    private final CatchRecordRepository catchRepository;
    private final FishingPostRepository postRepository;
    private final FishingPostCommentRepository commentRepository;
    private final FishingPostLikeRepository likeRepository;
    private final FishingUserFavoriteRepository favoriteRepository;
    private final PhotoStorageService photoStorage;
    private final WithdrawnName withdrawnName;

    /**
     * 여러 번 불러도 결과가 같다 — 앱이 중간에 실패해 다시 눌러도 안전해야 한다.
     *
     * @return 가려진 글·댓글 수 (로그용)
     */
    @Transactional
    public int withdraw(Long userId) {
        // 사진 파일은 트랜잭션이 되돌려 주지 않는다. 행을 먼저 지우고 파일을 지운다 —
        // 반대로 하면 롤백됐을 때 행은 살아 있는데 파일만 없는 기록이 남는다.
        List<CatchRecord> records = catchRepository.findAllByUser(userId);
        List<String> photoUrls = records.stream()
                .flatMap(record -> record.getPhotoUrls().stream())
                .toList();
        catchRepository.deleteAll(records);

        favoriteRepository.deleteAll(favoriteRepository.findByUserId(userId));
        likeRepository.deleteByUserId(userId);

        String masked = withdrawnName.of(userId);
        int posts = postRepository.maskAuthor(userId, masked);
        int comments = commentRepository.maskAuthor(userId, masked);

        photoUrls.forEach(url -> {
            if (url != null) {
                photoStorage.delete(url);
            }
        });

        log.info("탈퇴 정리: userId={} 조과 {}건·사진 {}장 삭제, 글 {}건·댓글 {}건 익명화",
                userId, records.size(), photoUrls.size(), posts, comments);
        return posts + comments;
    }
}
