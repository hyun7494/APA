import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/catch_record.dart';
import '../models/species.dart';
import '../services/photo_picker.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
import '../widgets/photo_placeholder.dart';
import '../widgets/photo_source_sheet.dart';
import '../widgets/press_scale.dart';
import '../widgets/reveal.dart';

/// 기록 추가 — 사진 · 어종 · 길이 · 일시 · 포인트 · 메모.
///
/// 단계별 페이지 전환은 마찰만 늘리므로 **한 화면에 세로로 전부 배치**한다
/// (기획서 5-4). 어종과 길이는 사용자가 직접 고르고 직접 잰다 — 자동 판별은
/// 오탐이 영구 기록을 오염시키기 때문에 Rev 2에서 폐기했다.
///
/// 시안 `Deep Tide Light.dc.html` Screen 04 기준. 일시·포인트는 접어 두지 않고
/// **자동 채움값을 처음부터 보여주고 고칠 수만 있게** 둔다 — 접어 두면 기본값이
/// 무엇인지 모른 채 저장하게 된다.
///
/// 시안과 다른 두 곳은 **서버가 아직 못 받기 때문**이다. 백엔드가 열리면 함께 바꾼다:
/// - 사진이 1장이다. 시안은 최대 5장(`PHOTOS · 1 / 5`)이지만
///   `fishing_user_catches.photo_url` 이 단일 컬럼이다.
/// - 길이가 필수다. 시안은 `길이 (선택)` 이지만 컬럼이 `NOT NULL` 이고
///   `CatchCreateRequest.normalizeLength()` 가 null 이면 400 을 낸다.
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

  /// 서버 `fishing.photo.max-bytes` 와 같은 값.

  /// 서버 `CatchCreateRequest.MEMO_LIMIT` 과 같은 값.
  /// 시안은 500 이지만 컬럼이 `VARCHAR(300)` 이라 넘기면 서버가 거절한다.
  static const _memoLimit = 300;

  Species? _species;
  PickedPhoto? _photo;
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

  bool get _ready => _photo != null && _species != null && (_length ?? 0) > 0;

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
                Reveal(child: Text('기록 추가', style: AppText.screenTitle)),
                const SizedBox(height: 22),

                const Reveal(index: 1, child: _SectionLabel('PHOTOS')),
                const SizedBox(height: 10),
                Reveal(index: 1, child: _PhotoField(
                  photo: _photo,
                  rare: _species?.rarity.isRare ?? false,
                  onPick: _pickPhoto,
                )),
                const SizedBox(height: AppSpacing.gap),

                Reveal(index: 2, child: _detailCard()),

                if (_underLegalSize) ...[
                  const SizedBox(height: 10),
                  _LegalSizeNotice(species: _species!),
                ],
                const SizedBox(height: AppSpacing.gap),

                Reveal(index: 3, child: _memoCard()),
                const SizedBox(height: AppSpacing.section),

                Reveal(
                  index: 4,
                  child: PrimaryButton(
                    label: _submitting ? '저장 중…' : '기록 저장',
                    icon: AppIcon.check,
                    onPressed: _ready && !_submitting ? _submit : null,
                  ),
                ),
                const SizedBox(height: 14),
                const Reveal(
                  index: 5,
                  child: NoticeLine(
                    text: '기록은 내 도감에만 저장됩니다. 게시판 공개는 저장 후 따로 선택합니다.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 어종 · 길이 · 일시 · 포인트 — 시안 Screen 04 의 한 장짜리 입력 카드.
  ///
  /// 넷을 각각 카드로 띄우면 화면이 세로로 길어져 저장 버튼이 접힌다.
  /// 시안대로 한 카드 안에 행으로 눕힌다.
  Widget _detailCard() {
    final species = _species;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          _tapRow(
            label: '어종',
            onTap: _pickSpecies,
            value: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  species?.name ?? '선택',
                  style: species == null
                      ? AppText.infoValue.copyWith(color: AppColors.faint)
                      : AppText.infoValue,
                ),
                if (species != null && species.rarity.isRare) ...[
                  const SizedBox(width: 7),
                  const LineIcon(
                    AppIcon.trophy,
                    size: 13,
                    color: AppColors.gold,
                    stroke: 1.5,
                  ),
                ],
              ],
            ),
          ),
          const CardDivider(),
          _inputRow(
            label: '길이',
            controller: _lengthController,
            hint: '0.0',
            suffix: 'cm',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // 소수점 1자리까지만
            formatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}\.?\d?')),
            ],
          ),
          const CardDivider(),
          _tapRow(
            label: '일시',
            onTap: _pickDateTime,
            // 시안은 분까지 보여준다 — 같은 날 여러 번 나간 기록이 구분된다.
            value: Text(
              DateFormat('MM.dd HH:mm').format(_caughtAt),
              style: AppText.infoValue,
            ),
          ),
          const CardDivider(),
          _inputRow(
            label: '포인트',
            controller: _spotController,
            hint: '기장 학리',
          ),
        ],
      ),
    );
  }

  /// 탭하면 선택기가 열리는 행.
  Widget _tapRow({
    required String label,
    required Widget value,
    required VoidCallback onTap,
  }) {
    return PressScale(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppText.rowLabel)),
            value,
            const SizedBox(width: 8),
            const LineIcon(
              AppIcon.chevronRight,
              size: 14,
              color: AppColors.faint,
              stroke: 1.5,
            ),
          ],
        ),
      ),
    );
  }

  /// 그 자리에서 바로 입력하는 행. 값이 오른쪽에 붙어 [_tapRow] 와 세로선이 맞는다.
  Widget _inputRow({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? suffix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: AppText.rowLabel),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => setState(() {}),
              keyboardType: keyboardType,
              inputFormatters: formatters,
              textAlign: TextAlign.right,
              cursorColor: AppColors.accent,
              style: AppText.infoValue,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppText.infoValue.copyWith(color: AppColors.faint),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: 4),
            Text(suffix, style: AppText.unit),
          ],
          // 오른쪽 화살표가 있는 행과 폭을 맞춘다.
          const SizedBox(width: 22),
        ],
      ),
    );
  }

  /// 메모 — 시안은 대문자 라벨 + 글자수 카운터를 카드 바깥이 아니라 안에 둔다.
  Widget _memoCard() {
    // 서버는 Java `String.length()` 로 재므로 Dart 의 UTF-16 길이와 셈이 같다.
    final used = _memoController.text.length;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('MEMO', style: AppText.overline)),
              Text(
                '$used / $_memoLimit',
                style: AppText.caption.copyWith(color: AppColors.disabled),
              ),
            ],
          ),
          TextField(
            controller: _memoController,
            onChanged: (_) => setState(() {}),
            maxLines: null,
            minLines: 3,
            maxLength: _memoLimit,
            cursorColor: AppColors.accent,
            style: AppText.bodySmall.copyWith(color: AppColors.body),
            decoration: const InputDecoration(
              hintText: '그날의 물때, 채비, 입질 타이밍처럼 다음에 도움이 될 것들',
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              // 카운터를 위에 직접 그리므로 기본 카운터는 지운다.
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }

  // ── 동작 ────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    // 시트·크기 한도·권한 안내는 글쓰기 화면과 공유한다 (`pickPhotoFromSheet`).
    final picked = await pickPhotoFromSheet(context, ref, onMessage: _toast);
    if (picked == null || !mounted) return;
    setState(() => _photo = picked);
  }

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));


  Future<void> _pickSpecies() async {
    final picked = await showModalBottomSheet<Species>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SpeciesPicker(all: ref.read(speciesMasterProvider)),
    );
    if (picked != null) setState(() => _species = picked);
  }

  /// 날짜를 고른 뒤 시각까지 이어서 묻는다. 시안이 분까지 보여주므로
  /// 날짜만 받으면 00:00 으로 저장돼 화면에 보이는 값과 어긋난다.
  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _caughtAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_caughtAt),
    );
    // 시각 선택을 취소하면 날짜만 반영하고 기존 시각을 지킨다.
    setState(() {
      _caughtAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _caughtAt.hour,
        time?.minute ?? _caughtAt.minute,
      );
    });
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    final result = await ref.read(fishingRepositoryProvider).registerCatch(
      CatchDraft(
        speciesId: _species!.id,
        lengthCm: _length!,
        caughtAt: _caughtAt,
        photo: _photo,
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

/// 섹션을 여는 대문자 라벨 — 시안의 `PHOTOS` · `MEMO`.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text, style: AppText.overline),
    );
  }
}

/// ① 사진 — 상단 큰 영역. 필수.
class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.photo,
    required this.rare,
    required this.onPick,
  });

  final PickedPhoto? photo;
  final bool rare;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final picked = photo;

    return AppCard(
      onTap: onPick,
      padding: const EdgeInsets.all(10),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          child: picked != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    // 경로가 아니라 바이트로 그린다 — 웹에서도 같은 코드가 돈다.
                    // 디코딩에 실패해도 화면이 깨지지 않게 줄무늬로 물러선다.
                    Image.memory(
                      picked.bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => PhotoPlaceholder(rare: rare),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.scrim,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '다시 고르기',
                          style: AppText.badgeSmall.copyWith(
                            color: AppColors.onAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
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
                      // '인증샷'이 아니라 '사진'이다 — 도감은 판정하지 않는다.
                      Text('사진 추가', style: AppText.sectionTitle),
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
