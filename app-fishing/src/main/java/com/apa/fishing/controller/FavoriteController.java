package com.apa.fishing.controller;

import com.apa.common.security.AuthenticatedUser;
import com.apa.fishing.dto.RegionGroupResponse;
import com.apa.fishing.service.FavoriteService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 즐겨찾는 권역 (계약서 3-7-5). 전부 <b>인증 필요</b> — {@code /fishing/me/**} 아래다.
 *
 * <p>★ <b>세 엔드포인트가 모두 같은 것을 돌려준다</b> — 갱신된 전체 목록이다.
 * 넣거나 뺀 뒤에 프론트가 목록을 다시 부르지 않아도 되고, 무엇보다 자기 쪽에서
 * 더하고 빼며 화면 상태를 지어내지 않게 된다 ({@code LikeResponse} 와 같은 생각이다).
 */
@RestController
@RequestMapping("/fishing/me/favorites")
@RequiredArgsConstructor
public class FavoriteController {

    private final FavoriteService favoriteService;

    @GetMapping
    public List<RegionGroupResponse> list(@AuthenticationPrincipal AuthenticatedUser user) {
        return favoriteService.myFavorites(user.userId());
    }

    /** 넣는다. 이미 있어도 200 이다 — 여러 번 눌러도 결과가 같아야 한다. */
    @PutMapping("/{regionGroupId}")
    public List<RegionGroupResponse> add(@AuthenticationPrincipal AuthenticatedUser user,
                                         @PathVariable Long regionGroupId) {
        return favoriteService.add(user.userId(), regionGroupId);
    }

    /** 뺀다. 없어도 200 이다. */
    @DeleteMapping("/{regionGroupId}")
    public List<RegionGroupResponse> remove(@AuthenticationPrincipal AuthenticatedUser user,
                                            @PathVariable Long regionGroupId) {
        return favoriteService.remove(user.userId(), regionGroupId);
    }
}
