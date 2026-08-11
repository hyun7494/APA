package com.apa.fishing.service;

import com.apa.fishing.dto.PostResponse;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;

/**
 * 게시판 임시 구현 — V1 스키마에 posts 테이블 자체가 없다 (Step 8에서 만든다).
 * 값은 프론트 시안(fishing_app/lib/data/mock_data.dart)의 4건을 그대로 옮긴 것이고,
 * Step 8에서 이 클래스 내용만 리포지토리 조회로 갈아끼우면 컨트롤러는 그대로 둔다.
 */
@Service
public class BoardService {

    public List<PostResponse> findPosts(String tag) {
        String category = tag == null || tag.isBlank() ? null : tag.trim().toUpperCase(Locale.ROOT);

        return samplePosts().stream()
                .filter(post -> category == null || post.category().equals(category))
                .toList();
    }

    /** createdAt 은 호출 시각 기준 상대값이다 — 프론트가 "2시간 전"/"어제"로 렌더한다. */
    private static List<PostResponse> samplePosts() {
        LocalDateTime now = LocalDateTime.now();
        return List.of(
                new PostResponse(1L, "CATCH", "오늘 학리에서 감성돔 4짜 손맛!",
                        "새벽 물때에 입질 폭발했습니다. 다들 출조하세요~",
                        "바다사나이", now.minusHours(2), 24, 8, true,
                        "부산 기장", "부산 기장", false),
                new PostResponse(2L, "CATCH", "참돔 시즌 시작! 새벽 물때 강추",
                        "사량도 옥동 갯바위 자리 좋습니다. 채비는 가볍게.",
                        "갯바위킹", now.minusDays(1), 41, 15, true,
                        "통영 사량도", "통영 사량도", false),
                new PostResponse(3L, "FREE", "초보도 잡았네요 ㅎㅎ 볼락 조황 좋아요",
                        "잔잔하고 수온 안정적이라 가족이랑 다녀왔어요.",
                        "손맛중독", now.minusHours(5), 12, 3, false,
                        "여수 돌산", "여수 돌산", false),
                new PostResponse(4L, "QUESTION", "영종도 우럭 포인트 추천 부탁드려요",
                        "주말에 처음 가보는데 선착장 근처 어떤가요?",
                        "릴사랑", now.minusDays(1), 5, 9, false,
                        "인천 영종도", "인천 영종도", false)
        );
    }
}
