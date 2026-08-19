import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../config/feature_flags.dart';
import '../models/catch_record.dart';
import '../models/species.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
import '../widgets/photo_placeholder.dart';
import '../widgets/press_scale.dart';
import '../widgets/reveal.dart';

/// 조과 등록 — 사진 · 어종 · 길이 · (선택) 장소·날짜·메모.
///
/// 단계별 페이지 전환은 마찰만 늘리므로 **한 화면에 세로로 전부 배치**한다
/// (기획서 5-4). 어종과 길이는 사용자가 직접 고르고 직접 잰다 — 자동 판별은
/// 오탐이 영구 기록을 오염시키기 때문에 Rev 2에서 폐기했다.
class CatchNewScreen extends ConsumerStatefulWidget {
  const CatchNewScreen({super.key, this.initialSpeciesId});

  /// 어종 상세에서 들어오면 그 어종이 미리 선택된다.
  final int? initialSpeciesId;

  @override
  ConsumerState<CatchNewScreen> createState() => _CatchNewScreenState();
}

class _CatchNewScreenState extends ConsumerState<CatchNewScreen> {
  final _lengthController = TextEditingController();
  final _spotController = TextEditingController();
  final _memoController = TextEditingController();

  Species? _species;
  bool _hasPhoto = false;
  bool _expanded = false;
  bool _submitting = false;
  DateTime _caughtAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    final id = widget.initialSpeciesId;
    if (id != null) {
      _species = ref
          .read(speciesMasterProvider)
          .where((s) => s.id == id)
          .firstOrNull;
    }
  }

  @override
  void dispose() {
    _lengthController.dispose();
    _spotController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  double? get _length => double.tryParse(_lengthController.text.trim());

  bool get _ready => _hasPhoto && _species != null && (_length ?? 0) > 0;

  /// 선택한 어종의 금지체장보다 작으면 안내 배너를 띄운다.
  /// **등록을 막지는 않는다** — 차단하면 사용자가 길이를 거짓으로 넣게 되고
  /// 데이터만 나빠진다 (기획서 5-4).
  bool get _underLegalSize {
    final min = _species?.minLegalSize;
    final len = _length;
    return min != null && len != null && len > 0 && len < min;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          BackRow(label: '도감으로', onTap: () => context.go('/collection')),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                20,
                AppSpacing.screen,
                AppSpacing.navClearance,
              ),
              children: [
                Reveal(child: Text('조과 등록', style: AppText.screenTitle)),
                const SizedBox(height: 22),

                Reveal(index: 1, child: _PhotoField(
                  hasPhoto: _hasPhoto,
                  rare: _species?.rarity.isRare ?? false,
                  onPick: _pickPhoto,
                )),
                const SizedBox(height: AppSpacing.gap),

                Reveal(
                  index: 2,
                  child: _SpeciesField(
                    species: _species,
                    onPick: _pickSpecies,
                  ),
                ),
                const SizedBox(height: AppSpacing.gap),

                Reveal(index: 3, child: _lengthField()),

                if (_underLegalSize) ...[
                  const SizedBox(height: 10),
                  _LegalSizeNotice(species: _species!),
                ],
                const SizedBox(height: AppSpacing.gap),

                Reveal(index: 4, child: _optionalSection()),
                const SizedBox(height: AppSpacing.section),

                Reveal(
                  index: 5,
                  child: PrimaryButton(
                    label: _submitting ? '등록 중…' : '도감에 등록하기',
                    icon: AppIcon.check,
                    onPressed: _ready && !_submitting ? _submit : null,
                  ),
                ),
                const SizedBox(height: 14),
                const Reveal(
                  index: 6,
                  child: NoticeLine(
                    text: '도감은 검증되지 않은 개인 기록입니다. 어종과 길이는 직접 입력한 값이 그대로 저장됩니다.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lengthField() {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LineIcon(
                AppIcon.ruler,
                size: 15,
                color: AppColors.accent,
                stroke: 1.4,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('길이', style: AppText.cardLabel)),
              Text('필수', style: AppText.caption),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: TextField(
                  controller: _lengthController,
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    // 소수점 1자리까지만
                    FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}\.?\d?')),
                  ],
                  cursorColor: AppColors.accent,
                  style: AppText.numberLarge,
                  decoration: const InputDecoration(
                    hintText: '0.0',
                    isDense: true,
                  ),
                ),
              ),
              Text('cm', style: AppText.numberMedium.copyWith(
                color: AppColors.faint,
                fontSize: 16,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _optionalSection() {
    return AppCard(
      padding: EdgeInsets.fromLTRB(18, 16, 18, _expanded ? 18 : 16),
      onTap: _expanded ? null : () => setState(() => _expanded = true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('선택 입력', style: AppText.cardLabel)),
              Text(
                _expanded ? '장소 · 날짜 · 메모' : '자세히 입력',
                style: AppText.caption,
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _expanded ? 0.25 : 0,
                duration: AppMotion.fast,
                curve: AppMotion.state,
                child: const LineIcon(
                  AppIcon.chevronRight,
                  size: 14,
                  color: AppColors.faint,
                  stroke: 1.5,
                ),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 16),
            _textRow(
              icon: AppIcon.pin,
              hint: '장소 (예: 기장 학리)',
              controller: _spotController,
            ),
            const Divider(height: 24),
            PressScale(
              onTap: _pickDate,
              child: Row(
                children: [
                  const LineIcon(
                    AppIcon.calendar,
                    size: 16,
                    color: AppColors.muted,
                    stroke: 1.4,
                  ),
                  const SizedBox(width: 11),
                  Expanded(child: Text('날짜', style: AppText.rowLabel)),
                  Text(
                    DateFormat('yyyy.MM.dd').format(_caughtAt),
                    style: AppText.numberMedium,
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            _textRow(
              icon: AppIcon.pencil,
              hint: '메모',
              controller: _memoController,
            ),
          ],
        ],
      ),
    );
  }

  Widget _textRow({
    required AppIcon icon,
    required String hint,
    required TextEditingController controller,
  }) {
    return Row(
      children: [
        LineIcon(icon, size: 16, color: AppColors.muted, stroke: 1.4),
        const SizedBox(width: 11),
        Expanded(
          child: TextField(
            controller: controller,
            cursorColor: AppColors.accent,
            style: AppText.body.copyWith(color: AppColors.ink),
            decoration: InputDecoration(hintText: hint, isDense: true),
          ),
        ),
      ],
    );
  }

  // ── 동작 ────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    if (!FeatureFlags.enablePhotoPicker) {
      // image_picker 연동 전 — 자리만 채우고 플로우는 그대로 확인할 수 있게 둔다.
      setState(() => _hasPhoto = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진 촬영·선택은 카메라 연동 후 지원됩니다')),
      );
      return;
    }
  }

  Future<void> _pickSpecies() async {
    final picked = await showModalBottomSheet<Species>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SpeciesPicker(all: ref.read(speciesMasterProvider)),
    );
    if (picked != null) setState(() => _species = picked);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _caughtAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _caughtAt = picked);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    final result = await ref.read(fishingRepositoryProvider).registerCatch(
      CatchDraft(
        speciesId: _species!.id,
        lengthCm: _length!,
        caughtAt: _caughtAt,
        spotName: _spotController.text.trim(),
        memo: _memoController.text.trim(),
      ),
    );

    ref.read(collectionRevisionProvider.notifier).state++;
    if (!mounted) return;

    if (result.firstCatch) {
      // 도감 칸이 새로 채워졌으면 획득 연출로 넘어간다.
      context.go('/catch/done/${result.record.speciesId}?catchId=${result.record.id}');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('기록이 추가되었습니다')));
      context.go('/collection/${result.record.speciesId}');
    }
  }
}

/// ① 사진 — 상단 큰 영역. 필수.
class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.hasPhoto,
    required this.rare,
    required this.onPick,
  });

  final bool hasPhoto;
  final bool rare;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onPick,
      padding: const EdgeInsets.all(10),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          child: hasPhoto
              ? PhotoPlaceholder(rare: rare)
              : ColoredBox(
                  color: AppColors.fill,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const LineIcon(
                        AppIcon.camera,
                        size: 30,
                        color: AppColors.disabled,
                        stroke: 1.4,
                      ),
                      const SizedBox(height: 12),
                      Text('인증샷 추가', style: AppText.sectionTitle),
                      const SizedBox(height: 4),
                      Text('촬영하거나 갤러리에서 고르세요', style: AppText.caption),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// ② 어종 — 탭하면 전체 화면 선택기가 열린다. 필수.
class _SpeciesField extends StatelessWidget {
  const _SpeciesField({required this.species, required this.onPick});

  final Species? species;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final s = species;

    return AppCard(
      onTap: onPick,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LineIcon(
                AppIcon.fish,
                size: 15,
                color: AppColors.accent,
                stroke: 1.4,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('어종', style: AppText.cardLabel)),
              Text('필수', style: AppText.caption),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  s?.name ?? '어종 선택',
                  style: s == null
                      ? AppText.cardLabel.copyWith(color: AppColors.faint)
                      : AppText.cardLabel,
                ),
              ),
              if (s != null && s.rarity.isRare) ...[
                const LineIcon(
                  AppIcon.trophy,
                  size: 14,
                  color: AppColors.gold,
                  stroke: 1.5,
                ),
                const SizedBox(width: 8),
              ],
              const LineIcon(
                AppIcon.chevronRight,
                size: 15,
                color: AppColors.faint,
                stroke: 1.5,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 금지체장 안내 — 정보이지 판정이 아니다 (기획서 7장).
class _LegalSizeNotice extends StatelessWidget {
  const _LegalSizeNotice({required this.species});

  final Species species;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: LineIcon(
              AppIcon.info,
              size: 15,
              color: AppColors.gold,
              stroke: 1.4,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${species.name}은 ${species.minLegalSize!.toStringAsFixed(0)}cm 이하 '
              '포획이 제한됩니다. 방류를 권장합니다.',
              style: AppText.caption.copyWith(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

/// 어종 선택기 — 검색창 + 그리드. 여기서는 미등록 어종도 전부 컬러로 보인다.
class _SpeciesPicker extends StatefulWidget {
  const _SpeciesPicker({required this.all});

  final List<Species> all;

  @override
  State<_SpeciesPicker> createState() => _SpeciesPickerState();
}

class _SpeciesPickerState extends State<_SpeciesPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final list = q.isEmpty
        ? widget.all
        : widget.all
              .where((s) => s.name.contains(q) || s.nameSci.contains(q))
              .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // 드래그 손잡이
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                10,
                AppSpacing.screen,
                14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('어종 선택', style: AppText.screenTitle),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        const LineIcon(
                          AppIcon.search,
                          size: 16,
                          color: AppColors.faint,
                          stroke: 1.5,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            autofocus: false,
                            onChanged: (v) => setState(() => _query = v),
                            cursorColor: AppColors.accent,
                            style: AppText.body.copyWith(color: AppColors.ink),
                            decoration: const InputDecoration(
                              hintText: '어종명 검색',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const ErrorView(message: '검색 결과가 없어요', height: 160)
                  : GridView.builder(
                      controller: controller,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screen,
                        0,
                        AppSpacing.screen,
                        AppSpacing.screen,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.82,
                          ),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _PickerTile(
                        species: list[i],
                        onTap: () => Navigator.pop(context, list[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 선택기 칸 — 도감과 달리 전부 컬러로 보여준다 (기획서 5-4).
class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.species, required this.onTap});

  final Species species;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rare = species.rarity.isRare;

    return PressScale(
      onTap: onTap,
      scale: 0.95,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                border: Border.all(
                  color: rare
                      ? AppColors.gold.withValues(alpha: 0.42)
                      : AppColors.line,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: PhotoPlaceholder(rare: rare),
            ),
          ),
          const SizedBox(height: 6),
          // 셀 높이가 딱 맞아떨어져서, 폰트 줄높이가 조금만 커져도 넘친다.
          Flexible(
            child: Text(
              species.name,
              style: AppText.tileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
