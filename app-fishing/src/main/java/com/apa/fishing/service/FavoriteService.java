package com.apa.fishing.service;

import com.apa.fishing.domain.FishingUserFavorite;
import com.apa.fishing.dto.RegionGroupResponse;
import com.apa.fishing.repository.FishingRegionRepository;
import com.apa.fishing.repository.FishingUserFavoriteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

/**
 * 즐겨찾는 권역 (계약서 3-7-5).
 *
 * <p>표({@code fishing_user_favorites})와 조회는 {@code V1} 부터 있었는데 <b>넣는 길이
 * 없어서 행이 늘 0 이었다.</b> 마이페이지가 그 0 을 그리고 있었고, 그래서 2026-08-30 에
 * 칩·개수·메뉴를 화면에서 걷어냈다. 이제 쓰는 쪽이 생겼으니 셋이 함께 돌아온다.
 *
 * <p>★ <b>토글이 아니라 넣기/빼기다.</b> 계약서 초안은 {@code PUT} 하나로 뒤집는
 * 모양이었는데, 그러면 응답이 유실돼 앱이 재시도할 때 <b>도로 꺼진다</b> — 사용자는
 * 별을 한 번 눌렀는데 결과가 두 번 누른 것이 된다. 별을 누르는 쪽은 언제나 원하는
 * 최종 상태를 알고 있으므로, 그 상태를 그대로 보내게 하고 여러 번 보내도 같게 만든다.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class FavoriteService {

    private final FishingUserFavoriteRepository favoriteRepository;
    private final FishingRegionRepository regionRepository;
    private final RegionService regionService;

    /** 내 즐겨찾기. 넣고 뺀 뒤에도 <b>같은 모양</b>을 돌려준다 — 아래 주석 참고. */
    public List<RegionGroupResponse> myFavorites(Long userId) {
        return regionService.findByIds(regionIdsOf(userId));
    }

    /**
     * 넣는다. 이미 있으면 아무 일도 없다.
     *
     * <p>중복 저장을 막으려고 미리 조회하지 않고 {@code existsById} 하나로 끝낸다 —
     * 어차피 복합 기본키가 마지막 방어선이다.
     */
    @Transactional
    public List<RegionGroupResponse> add(Long userId, Long regionGroupId) {
        requireRegion(regionGroupId);

        var key = new FishingUserFavorite.Key(userId, regionGroupId);
        if (!favoriteRepository.existsById(key)) {
            favoriteRepository.save(FishingUserFavorite.of(userId, regionGroupId));
        }
        return myFavorites(userId);
    }

    /** 뺀다. 없으면 아무 일도 없다 — 두 번 눌러도 오류를 내지 않는다. */
    @Transactional
    public List<RegionGroupResponse> remove(Long userId, Long regionGroupId) {
        requireRegion(regionGroupId);

        favoriteRepository.deleteById(new FishingUserFavorite.Key(userId, regionGroupId));
        return myFavorites(userId);
    }

    private List<Long> regionIdsOf(Long userId) {
        return favoriteRepository.findByUserId(userId).stream()
                .map(FishingUserFavorite::getRegionGroupId)
                .toList();
    }

    /**
     * ⚠️ 없는 권역을 그냥 저장하면 <b>FK 위반이 500 으로 나간다.</b> 사용자에게는 서버가
     * 고장 난 것처럼 보이지만 실제로는 잘못된 요청이라, 여기서 404 로 끊는다.
     *
     * <p>실제로 일어날 수 있는 일이다 — V14 가 권역을 갈아엎으면서 옛 id 가 사라졌고,
     * 그때 화면에 남아 있던 앱은 없는 id 를 들고 있었다.
     */
    private void requireRegion(Long regionGroupId) {
        if (regionGroupId == null || !regionRepository.existsById(regionGroupId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "지역을 찾을 수 없습니다");
        }
    }
}
