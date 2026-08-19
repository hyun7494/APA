import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/catch_record.dart';
import '../models/species.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
import '../widgets/collection_progress.dart';
import '../widgets/photo_placeholder.dart';
import '../widgets/reveal.dart';

/// 등록 완료 — 도감 칸이 새로 채워진 순간.
///
/// 기획서 2-3: 이 연출이 도감형 앱 리텐션의 핵심이라 생략하지 않는다.
/// 흑백 → 컬러 전환을 400ms에 한 번 재생하고 "몇 번째 칸이 채워졌는지"를 띄운다.
/// 희귀 등급은 골드 카드로만 축하한다 — 컨페티 같은 장식은 넣지 않는다.
class CatchSuccessScreen extends ConsumerWidget {
  const CatchSuccessScreen({
    super.key,
    required this.speciesId,
    this.catchId,
  });

  final int speciesId;
  final int? catchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(collectionEntryProvider(speciesId));
    final summary = ref.watch(collectionSummaryProvider);

    return SafeArea(
      child: entry.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.screen),
          child: LoadingView(height: 320, lines: 6),
        ),
        error: (e, _) => ErrorView(message: '기록을 불러오지 못했어요', error: e),
        data: (e) => _Body(
          entry: e,
          summary: summary.valueOrNull,
          records: ref.watch(catchesProvider(speciesId)).valueOrNull,
          catchId: catchId,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.entry,
    required this.summary,
    required this.records,
    required this.catchId,
  });

  final CollectionEntry entry;
  final CollectionSummary? summary;
  final List<CatchRecord>? records;
  final int? catchId;

  @override
  Widget build(BuildContext context) {
    final species = entry.species;
    final rare = species.rarity.isRare;
    final record = records?.where((r) => r.id == catchId).firstOrNull;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        32,
        AppSpacing.screen,
        AppSpacing.screen,
      ),
      children: [
        Reveal(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rare ? '희귀 어종 획득' : '새로 채운 칸',
                style: AppText.cardLabel.copyWith(
                  color: rare ? AppColors.gold : AppColors.accentDark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '도감 ${summary?.owned ?? entry.species.displayOrder}번째 칸이\n채워졌습니다',
                style: AppText.pageTitle,
              ),
              const SizedBox(height: 8),
              Text(
                [
                  species.name,
                  if (rare) '희귀 등급',
                  if (record != null && record.spotName.isNotEmpty)
                    record.spotName,
                ].join('  ·  '),
                style: AppText.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),

        // 주인공 — 흑백에서 컬러로 살아나는 인증샷
        Reveal(
          index: 1,
          child: AppCard(
            padding: const EdgeInsets.all(10),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _SaturationReveal(child: PhotoPlaceholder(rare: rare)),
                    // 길이 배지는 채도 연출 밖에 둔다 — 글자가 같이
                    // 흑백으로 죽었다 살아나면 읽는 데 방해가 된다.
                    if (record != null)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.scrim,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '${record.lengthCm.toStringAsFixed(1)}cm',
                            style: AppText.badgeSmall.copyWith(
                              color: AppColors.onAccent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        Reveal(
          index: 2,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(species.name, style: AppText.screenTitle),
                    if (species.nameSci.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        species.nameSci,
                        style: AppText.badgeSmall.copyWith(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (record != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      record.lengthCm.toStringAsFixed(1),
                      style: AppText.numberLarge.copyWith(
                        color: rare ? AppColors.gold : AppColors.accentDark,
                      ),
                    ),
                    Text('cm', style: AppText.unit),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),

        if (summary != null)
          Reveal(
            index: 3,
            child: AppCard(
              radius: AppRadius.cardSmall,
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('도감 진행도', style: AppText.rowLabel),
                      ),
                      Text(
                        '${summary!.owned}',
                        style: AppText.numberMedium.copyWith(fontSize: 17),
                      ),
                      Text(
                        ' / ${summary!.total}',
                        style: AppText.numberMedium.copyWith(
                          color: AppColors.faint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CollectionProgressBar(summary: summary!),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.section),

        Reveal(
          index: 4,
          child: PrimaryButton(
            label: '도감에서 보기',
            icon: AppIcon.book,
            onPressed: () => context.go('/collection/${species.id}'),
          ),
        ),
        const SizedBox(height: AppSpacing.gap),
        Reveal(
          index: 5,
          child: SecondaryButton(
            label: '게시판에 조황 올리기',
            icon: AppIcon.chat,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('글쓰기는 로그인 연동 후 지원됩니다')),
            ),
          ),
        ),
      ],
    );
  }
}

/// 흑백 → 컬러 전환을 1회 재생한다.
///
/// 채도 보간은 [ColorFilter.matrix]의 휘도 행렬과 항등 행렬을 t로 섞어서 만든다.
/// (기획서 2-3의 `ColorFiltered` 팁을 애니메이션으로 확장한 것)
class _SaturationReveal extends StatefulWidget {
  const _SaturationReveal({required this.child});

  final Widget child;

  @override
  State<_SaturationReveal> createState() => _SaturationRevealState();
}

class _SaturationRevealState extends State<_SaturationReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void initState() {
    super.initState();
    // 화면이 자리를 잡은 뒤에 살아나야 눈에 걸린다.
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// t=0 완전 흑백, t=1 원본.
  static List<double> _matrix(double t) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    double mix(double gray, double identity) => gray + (identity - gray) * t;
    return <double>[
      mix(lr, 1), mix(lg, 0), mix(lb, 0), 0, 0,
      mix(lr, 0), mix(lg, 1), mix(lb, 0), 0, 0,
      mix(lr, 0), mix(lg, 0), mix(lb, 1), 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(_matrix(t)),
          child: Opacity(opacity: 0.5 + 0.5 * t, child: child),
        );
      },
      child: widget.child,
    );
  }
}
