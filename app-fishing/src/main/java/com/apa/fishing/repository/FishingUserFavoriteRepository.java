package com.apa.fishing.repository;

import com.apa.fishing.domain.FishingUserFavorite;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface FishingUserFavoriteRepository
        extends JpaRepository<FishingUserFavorite, FishingUserFavorite.Key> {

    /** 개수는 이 목록의 크기로 센다 — 같은 수를 두 번 질의할 이유가 없다. */
    List<FishingUserFavorite> findByUserId(Long userId);
}
