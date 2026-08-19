package com.apa.fishing.controller;

import com.apa.common.security.AuthenticatedUser;
import com.apa.fishing.dto.CollectionEntryResponse;
import com.apa.fishing.service.CollectionService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 내 도감 (기획서 v2 4-2).
 *
 * <p><b>인증 필수다.</b> {@code /fishing/me/**} 는 SecurityConfig 가 막고 있어 비로그인은 401 을 받는다.
 * 프론트는 그 401 을 "로그인 안 됨"으로 삼키고 {@code GET /fishing/species} 로 갈아타 전 칸이 잠긴
 * 마스터 도감을 그린다 — 도감 탭 자체는 비로그인도 열려야 하기 때문이다 (기획서 5-5).
 *
 * <p>기획서는 응답을 {@code { total, ownedCount, items:[...] }} 로 적었지만 <b>순수 배열로 내린다.</b>
 * 프론트({@code RemoteFishingRepository.fetchCollection})가 배열로 파싱하고, 진행률은 그 배열에서
 * 바로 세어 쓴다 — 같은 수를 서버가 또 세어 보내면 어긋날 자리만 생긴다.
 */
@RestController
@RequestMapping("/fishing/me/collection")
@RequiredArgsConstructor
public class CollectionController {

    private final CollectionService collectionService;

    @GetMapping
    public List<CollectionEntryResponse> myCollection(@AuthenticationPrincipal AuthenticatedUser user) {
        return collectionService.myCollection(user.userId());
    }

    @GetMapping("/{speciesId}")
    public CollectionEntryResponse myEntry(@AuthenticationPrincipal AuthenticatedUser user,
                                           @PathVariable Long speciesId) {
        return collectionService.myEntry(user.userId(), speciesId);
    }
}
