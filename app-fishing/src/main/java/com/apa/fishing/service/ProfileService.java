package com.apa.fishing.service;

import com.apa.common.security.AuthenticatedUser;
import com.apa.fishing.domain.FishingUserFavorite;
import com.apa.fishing.dto.ProfileResponse;
import com.apa.fishing.dto.RegionGroupResponse;
import com.apa.fishing.repository.CatchRecordRepository;
import com.apa.fishing.repository.FishingPostRepository;
import com.apa.fishing.repository.FishingUserFavoriteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * 마이페이지 집계 (계약서 3-7).
 *
 * <p>세 가지를 세고 즐겨찾는 지역을 붙인다. 전부 이 사용자 것만 본다.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ProfileService {

    /**
     * 조과 몇 개마다 한 레벨 오르는가.
     *
     * <p>⚠️ <b>임시 규칙이다.</b> 기획서에 레벨 산식이 없어서 정한 값이고, 화면에
     * 숫자가 하나 필요해서 존재한다. 레벨을 실제로 쓰기로 하면 — 도감 수집률을 볼지,
     * 희귀도에 가중치를 줄지 — 그때 여기만 고치면 된다.
     */
    private static final int CATCHES_PER_LEVEL = 5;

    private final CatchRecordRepository catchRecordRepository;
    private final FishingPostRepository postRepository;
    private final FishingUserFavoriteRepository favoriteRepository;
    private final RegionService regionService;

    public ProfileResponse myProfile(AuthenticatedUser user) {
        int catchCount = (int) catchRecordRepository.countByUserId(user.userId());
        int postCount = (int) postRepository.countByUserId(user.userId());

        List<Long> favoriteRegionIds = favoriteRepository.findByUserId(user.userId()).stream()
                .map(FishingUserFavorite::getRegionGroupId)
                .toList();
        List<RegionGroupResponse> favoriteRegions = regionService.findByIds(favoriteRegionIds);

        return new ProfileResponse(
                nicknameOf(user),
                level(catchCount),
                // 프론트가 level 로 조립한다. ProfileResponse 주석 참고.
                "",
                catchCount,
                postCount,
                favoriteRegionIds.size(),
                favoriteRegions);
    }

    /**
     * 토큰에 닉네임이 없을 수도 있다 — 카카오에서 프로필 제공에 동의하지 않은 사용자가
     * 그렇다. 비워 보내면 화면에 이름 자리가 빈 채로 남으므로 계약서의 기본값을 쓴다.
     */
    private String nicknameOf(AuthenticatedUser user) {
        String nickname = user.nickname();
        return nickname == null || nickname.isBlank() ? "조사님" : nickname;
    }

    private int level(int catchCount) {
        return 1 + catchCount / CATCHES_PER_LEVEL;
    }
}
