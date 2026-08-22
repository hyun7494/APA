import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/catch_record.dart';
import '../models/species.dart';
import '../services/login_gate.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
import '../widgets/authed_photo.dart';
import '../widgets/reveal.dart';

/// 어종 상세 — 도감 페이지.
///
/// 주인공은 도감 설명이 아니라 **내가 잡은 사진**이다. 어종 지식은 아래 표로
/// 내렸다. 미등록이면 자물쇠 면과 함께 "아직 만나지 못했어요"를 띄운다.
class SpeciesDetailScreen extends ConsumerWidget {
  const SpeciesDetailScreen({super.key, required this.speciesId});

  final int speciesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(collectionEntryProvider(speciesId));
    final records = ref.watch(catchesProvider(speciesId));

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          BackRow(label: '어류 도감', onTap: () => context.go('/collection')),
          Expanded(
            child: entry.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.screen),
                child: LoadingView(height: 320, lines: 7),
              ),
              error: (e, _) =>
                  ErrorView(message: '어종을 불러오지 못했어요', error: e, height: 320),
              data: (e) => _Body(entry: e, records: records),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.entry, required this.records});

  final CollectionEntry entry;
  final AsyncValue<List<CatchRecord>> records;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final species = entry.species;
    final owned = entry.owned;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        18,
        AppSpacing.screen,
        AppSpacing.navClearance,
      ),
      children: [
        Reveal(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '도감 · ${species.displayOrder}번',
                  style: AppText.caption,
                ),
              ),
              if (species.rarity.isRare)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.32),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LineIcon(
                        AppIcon.trophy,
                        size: 12,
                        color: AppColors.gold,
                        stroke: 1.5,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '희귀',
                        style: AppText.badge.copyWith(color: AppColors.gold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 주인공 — 내 인증샷 (미등록이면 자물쇠 면)
        Reveal(
          index: 1,
          child: AppCard(
            padding: const EdgeInsets.all(10),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                child: owned
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          AuthedPhoto(
                            path: entry.coverPhotoUrl,
                            rare: species.rarity.isRare,
                          ),
                          // 최대 길이는 사진 위 배지로 얹는다. 플레이스홀더가
                          // 실제 사진으로 바뀌어도 이 자리는 그대로다.
                          if (entry.bestLengthCm != null)
                            Positioned(
                              left: 10,
                              bottom: 10,
                              child: _PhotoBadge(
                                text:
                                    '${entry.bestLengthCm!.toStringAsFixed(1)}cm',
                              ),
                            ),
                        ],
                      )
                    : const _LockedFace(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        Reveal(
          index: 2,
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
              if (species.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(species.description, style: AppText.body),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),

        // 내 기록 요약
        if (owned) ...[
          Reveal(
            index: 3,
            child: AppCard(
              radius: AppRadius.cardSmall,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
              child: Row(
                children: [
                  Expanded(
                    child: MetricColumn(
                      icon: AppIcon.ruler,
                      label: '내 최대',
                      value: entry.bestLengthCm?.toStringAsFixed(1) ?? '—',
                      unit: 'cm',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricColumn(
                      icon: AppIcon.fish,
                      label: '포획',
                      value: '${entry.catchCount}',
                      unit: '회',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.gap),
        ] else ...[
          Reveal(
            index: 3,
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Column(
                children: [
                  const LineIcon(
                    AppIcon.lock,
                    size: 24,
                    color: AppColors.disabled,
                    stroke: 1.4,
                  ),
                  const SizedBox(height: 12),
                  Text('아직 만나지 못했어요', style: AppText.sectionTitle),
                  const SizedBox(height: 5),
                  Text(
                    '사진과 길이를 등록하면 이 칸이 채워집니다.',
                    style: AppText.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.gap),
        ],

        // 어종 정보 표
        Reveal(
          index: 4,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            child: Column(
              children: [
                _InfoRow(
                  icon: AppIcon.moon,
                  label: '주 서식',
                  value: species.habitat.label,
                ),
                if (species.season != null) ...[
                  const Divider(),
                  _InfoRow(
                    icon: AppIcon.calendar,
                    label: '제철',
                    value: species.season!,
                  ),
                ],
                if (species.minLegalSize != null) ...[
                  const Divider(),
                  _InfoRow(
                    icon: AppIcon.ruler,
                    label: '포획금지체장',
                    value: '${species.minLegalSize!.toStringAsFixed(0)}cm 이하',
                  ),
                ],
                if (species.closedSeason != null) ...[
                  const Divider(),
                  _InfoRow(
                    icon: AppIcon.info,
                    label: '금어기',
                    value: species.closedSeason!,
                  ),
                ],
              ],
            ),
          ),
        ),

        if (species.minLegalSize != null || species.closedSeason != null) ...[
          const SizedBox(height: 12),
          const Reveal(
            index: 5,
            child: NoticeLine(
              text: '규정은 변경될 수 있으니 해양수산부 고시를 확인하세요. '
                  '앱은 위법 여부를 판정하지 않습니다.',
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.section),

        // 내 기록 목록
        Reveal(
          index: 6,
          child: SectionLabel(
            label: 'MY RECORDS',
            padded: false,
            trailing: Text(
              '${entry.catchCount}',
              style: AppText.badgeSmall.copyWith(color: AppColors.muted),
            ),
          ),
        ),
        const SizedBox(height: 14),

        records.when(
          loading: () => const LoadingView(height: 120, lines: 3),
          error: (e, _) => ErrorView(message: '기록을 불러오지 못했어요', error: e),
          data: (list) {
            if (list.isEmpty) {
              return const ErrorView(message: '아직 기록이 없어요', height: 100);
            }
            return Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.gap),
                  Reveal(
                    index: 7 + i,
                    child: _RecordRow(
                      record: list[i],
                      rare: species.rarity.isRare,
                      onDelete: () => _confirmDelete(context, ref, list[i]),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.section),

        Reveal(
          index: 8,
          child: PrimaryButton(
            // 시안 Screen 03 의 버튼 문구.
            label: '기록 추가하기',
            icon: AppIcon.camera,
            onPressed: () => requireLogin(
              context,
              ref,
              destination: '/catch/new?speciesId=${species.id}',
              reason: '조과를 등록하려면 로그인이 필요해요.\n기록은 계정에 저장됩니다.',
            ),
          ),
        ),
      ],
    );
  }

  /// 기획서 3-3: 잘못 등록한 어종을 되돌릴 수 없으면 도감 신뢰가 무너진다.
  /// 마지막 기록이 지워지면 칸도 미등록으로 돌아간다.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CatchRecord record,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final last = entry.catchCount <= 1;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('기록을 삭제할까요?', style: AppText.cardLabel),
        content: Text(
          last
              ? '이 어종의 마지막 기록입니다. 삭제하면 도감 칸이 다시 미등록으로 돌아갑니다.'
              : '${record.speciesName} ${record.lengthCm.toStringAsFixed(1)}cm 기록이 지워집니다.',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소', style: AppText.rowValue.copyWith(color: AppColors.sub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '삭제',
              style: AppText.rowValue.copyWith(color: AppColors.alert),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await ref.read(fishingRepositoryProvider).deleteCatch(record.id);
    ref.read(collectionRevisionProvider.notifier).state++;
    messenger.showSnackBar(const SnackBar(content: Text('기록을 삭제했습니다')));
  }
}

/// 미등록 어종의 큰 자물쇠 면.
class _LockedFace extends StatelessWidget {
  const _LockedFace();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.fill,
      child: const Center(
        child: LineIcon(
          AppIcon.lock,
          size: 40,
          color: AppColors.disabled,
          stroke: 1.3,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final AppIcon icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          LineIcon(icon, size: 16, color: AppColors.muted, stroke: 1.4),
          const SizedBox(width: 11),
          Expanded(child: Text(label, style: AppText.rowLabel)),
          Text(value, style: AppText.sectionTitle),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.record,
    required this.rare,
    required this.onDelete,
  });

  final CatchRecord record;
  final bool rare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AuthedPhoto(
                path: record.photoUrl,
                rare: rare,
                stripe: 5,
                thumb: true,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      record.lengthCm.toStringAsFixed(1),
                      style: AppText.numberMedium.copyWith(fontSize: 17),
                    ),
                    const SizedBox(width: 2),
                    Text('cm', style: AppText.unit),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    DateFormat('yyyy.MM.dd').format(record.caughtAt),
                    if (record.spotName.isNotEmpty) record.spotName,
                  ].join('  ·  '),
                  style: AppText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconTapButton(
            icon: AppIcon.trash,
            onPressed: onDelete,
            size: 34,
          ),
        ],
      ),
    );
  }
}

/// 사진 위에 얹는 반투명 배지 — 최고 기록 길이.
class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.scrim,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      text,
      style: AppText.badgeSmall.copyWith(color: AppColors.onAccent),
    ),
  );
}
