import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../services/location_service.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
import '../widgets/press_scale.dart';
import '../widgets/rating_badge.dart';
import '../widgets/reveal.dart';

/// 지역 검색 — 검색창, 현재 위치로 찾기, 전체 지역 리스트.
class RegionSearchScreen extends ConsumerStatefulWidget {
  const RegionSearchScreen({super.key});

  @override
  ConsumerState<RegionSearchScreen> createState() => _RegionSearchScreenState();
}

class _RegionSearchScreenState extends ConsumerState<RegionSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  /// 위치를 받아 왔으면 그 좌표. 아직 안 눌렀거나 거부당했으면 null 이다.
  ({double lat, double lon})? _at;
  bool _locating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 권역을 고르면 그 권역의 포인트 목록으로.
  void _pickRegion(RegionGroup region) {
    ref.read(selectedRegionIdProvider.notifier).state = region.id;
    context.go('/score');
  }

  /// 포인트를 고르면 **그 포인트 상세로 바로** 간다. 권역을 거쳐 다시 찾게 하지 않는다.
  ///
  /// 상세에서 뒤로 가면 그 포인트가 속한 권역 목록이어야 자연스러우므로 선택도 옮겨 둔다.
  void _pickSpot(Spot spot) {
    ref.read(selectedRegionIdProvider.notifier).state = spot.regionGroupId;
    context.go('/score/${spot.id}');
  }

  /// 기기 위치를 받아 가까운 포인트를 띄운다.
  ///
  /// 거부는 오류가 아니라 사용자의 선택이라, 오류 상자 대신 스낵바 한 줄로 알린다
  /// ([LocationService] 주석 참고).
  Future<void> _findNearby() async {
    setState(() => _locating = true);
    final result = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    setState(() => _locating = false);

    switch (result) {
      case LocationFound(:final latitude, :final longitude):
        // 검색어가 남아 있으면 두 목록이 겹쳐 보인다. 위치로 찾을 때는 비운다.
        _controller.clear();
        setState(() {
          _query = '';
          _at = (lat: latitude, lon: longitude);
        });
      case LocationDenied(:final message, :final openSettings):
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              // 영구 거부는 앱 안에서 풀 방법이 없다. 설정으로 보내 준다.
              action: openSettings
                  ? SnackBarAction(
                      label: '설정',
                      onPressed: Geolocator.openAppSettings,
                    )
                  : null,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(regionSearchProvider(_query));
    // 검색어가 있을 때만 포인트를 찾는다. 빈 검색어에 전체를 쏟으면 `전체 지역` 위에
    // 51곳이 통째로 깔린다.
    final spots = _query.trim().isEmpty
        ? const AsyncValue<List<Spot>>.data([])
        : ref.watch(spotSearchProvider(_query));

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          BackRow(label: '낚시 지수', onTap: () => context.go('/score')),
          const SizedBox(height: 22),
          const Reveal(
            child: ScreenHeader(title: '지역 선택'),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                24,
                AppSpacing.screen,
                AppSpacing.navClearance,
              ),
              children: [
                Reveal(
                  index: 1,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        LineIcon(
                          AppIcon.search,
                          size: 17,
                          color: AppColors.faint,
                          stroke: 1.5,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            onChanged: (v) => setState(() => _query = v),
                            cursorColor: AppColors.accent,
                            style: AppText.body.copyWith(color: AppColors.ink),
                            decoration: const InputDecoration(
                              hintText: '지역 또는 포인트 검색',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.gap),
                Reveal(
                  index: 2,
                  child: PrimaryButton(
                    label: _locating ? '위치 확인 중…' : '현재 위치로 찾기',
                    icon: AppIcon.pin,
                    onPressed: _locating ? null : _findNearby,
                  ),
                ),
                const SizedBox(height: AppSpacing.section),

                // 위치로 찾았으면 그 결과가 화면의 주인이다. 검색어와 섞으면
                // 무엇에 대한 목록인지 알 수 없다.
                ...switch (_at) {
                  null => const <Widget>[],
                  final at => [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('가까운 포인트', style: AppText.sectionTitle),
                          ),
                          PressScale(
                            onTap: () => setState(() => _at = null),
                            scale: 0.94,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: Text('지우기', style: AppText.caption),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ref
                        .watch(nearbySpotsProvider(at))
                        .when(
                          loading: () =>
                              const LoadingView(height: 160, lines: 4),
                          error: (e, _) => ErrorView(
                            message: '가까운 포인트를 불러오지 못했어요',
                            error: e,
                          ),
                          data: (list) => Column(
                            children: [
                              for (var i = 0; i < list.length; i++) ...[
                                if (i > 0) const SizedBox(height: AppSpacing.gap),
                                _SpotRow(
                                  spot: list[i],
                                  onTap: () => _pickSpot(list[i]),
                                ),
                              ],
                            ],
                          ),
                        ),
                    const SizedBox(height: AppSpacing.section),
                  ],
                },

                // 포인트가 걸리면 **먼저** 보여준다. `울릉` 을 친 사람이 원하는 건
                // 권역이 아니라 그 포인트다.
                ...switch (spots.valueOrNull) {
                  null || [] => const <Widget>[],
                  final list => [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text('포인트', style: AppText.sectionTitle),
                    ),
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.gap),
                      Reveal(
                        index: i + 3,
                        child: _SpotRow(
                          spot: list[i],
                          onTap: () => _pickSpot(list[i]),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.section),
                  ],
                },

                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _query.isEmpty ? '전체 지역' : '지역',
                    style: AppText.sectionTitle,
                  ),
                ),

                results.when(
                  loading: () => const LoadingView(height: 160, lines: 4),
                  error: (e, _) =>
                      ErrorView(message: '지역을 불러오지 못했어요', error: e),
                  data: (list) {
                    if (list.isEmpty) {
                      // 포인트가 걸렸다면 그쪽이 이미 답이다. 그때까지 `없어요` 를
                      // 띄우면 눈앞에 결과를 두고 없다고 말하는 꼴이 된다.
                      if (spots.valueOrNull?.isNotEmpty ?? false) {
                        return const SizedBox.shrink();
                      }
                      return const ErrorView(message: '검색 결과가 없어요', height: 120);
                    }
                    return Column(
                      children: [
                        for (var i = 0; i < list.length; i++) ...[
                          if (i > 0) const SizedBox(height: AppSpacing.gap),
                          Reveal(
                            index: i + 3,
                            child: _RegionRow(
                              region: list[i],
                              onTap: () => _pickRegion(list[i]),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 검색에 걸린 포인트 한 줄. 지역 행과 모양을 맞추되 **어느 권역인지**를 함께 보인다 —
/// `울릉도` 만 있으면 그게 동해인지 남해인지 알 수 없다.
class _SpotRow extends StatelessWidget {
  const _SpotRow({required this.spot, required this.onTap});

  final Spot spot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      child: Row(
        children: [
          LineIcon(AppIcon.pin, size: 16, color: AppColors.muted, stroke: 1.4),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spot.name,
                  style: AppText.sectionTitle.copyWith(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  // ⚠️ "여기서" 를 빼지 말 것. KHOA 예보지점 이름에 거리가 들어 있어서
                  //    (`강릉항 북동(2km)`) 그냥 "2.4km" 라고 쓰면 한 카드에 km 가 둘이 되고,
                  //    이름 속 숫자가 내 위치에서의 거리로 읽힌다.
                  spot.distanceKm == null
                      ? spot.regionName
                      : '${spot.regionName} · 여기서 ${spot.distanceKm!.toStringAsFixed(1)}km',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Text(
            '${Spot.metric(spot.waterTemp)}℃',
            style: AppText.numberMedium.copyWith(color: AppColors.muted),
          ),
          const SizedBox(width: 10),
          RatingBadge(rating: spot.rating, compact: true),
        ],
      ),
    );
  }
}

class _RegionRow extends StatelessWidget {
  const _RegionRow({required this.region, required this.onTap});

  final RegionGroup region;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final temp = region.previewWaterTemp;
    final rating = region.previewRating;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  region.name,
                  style: AppText.sectionTitle.copyWith(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(region.area, style: AppText.caption),
              ],
            ),
          ),
          if (temp != null) ...[
            Text(
              '${temp.toStringAsFixed(1)}℃',
              style: AppText.numberMedium.copyWith(color: AppColors.muted),
            ),
            const SizedBox(width: 10),
          ],
          if (rating != null) RatingBadge(rating: rating, compact: true),
        ],
      ),
    );
  }
}
