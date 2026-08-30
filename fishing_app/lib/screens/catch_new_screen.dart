import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/catch_record.dart';
import '../models/species.dart';
import '../services/fishing_repository.dart';
import '../services/photo_picker.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/async_view.dart';
import '../widgets/authed_photo.dart';
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
/// 시안과 어긋나 있던 셋(사진 1장 · 길이 필수 · 메모 300자)은 **서버가 못 받아서**였다.
/// V11 이 표를 열어 줘서 지금은 시안 그대로다 — 사진 최대 5장, 길이는 선택, 메모 500자.
/// 고치기는 이 화면을 그대로 쓴다 ([catchId] 가 있으면 고치기 모드) — 글쓰기·글 고치기가
/// `PostNewScreen` 하나를 쓰는 것과 같은 이유다. 따로 만들면 사진 한도·메모 글자수·
/// 금지체장 안내가 두 곳에서 어긋난다.
class CatchNewScreen extends ConsumerStatefulWidget {
  const CatchNewScreen({super.key, this.initialSpeciesId, this.catchId});

  /// 어종 상세에서 들어오면 그 어종이 미리 선택된다.
  final int? initialSpeciesId;

  /// 있으면 그 기록을 고친다. 없으면 새 기록이다.
  final int? catchId;

  bool get isEdit => catchId != null;

  @override
  ConsumerState<CatchNewScreen> createState() => _CatchNewScreenState();
}

class _CatchNewScreenState extends ConsumerState<CatchNewScreen> {
  final _lengthController = TextEditingController();
  final _spotController = TextEditingController();
  final _memoController = TextEditingController();

  /// 서버 `CatchCreateRequest.MEMO_LIMIT` 과 같은 값.
  /// V11 이 컬럼을 `VARCHAR(500)` 으로 늘려 시안의 한도를 그대로 쓴다.
  static const _memoLimit = 500;

  Species? _species;

  /// 사진들. 순서가 그대로 서버에 가고 첫 장이 도감 칸의 표지가 된다.
  ///
  /// 고치기 모드에서는 **이미 서버에 있는 장([_Kept])과 방금 고른 장([_Added])이
  /// 섞인다.** 서버가 "남긴 장 뒤에 새 장을 붙이는" 규칙이라 순서를 임의로 바꿀 수는
  /// 없는데, 여기서는 뒤에 더하고 빼기만 하므로 그 규칙이 저절로 지켜진다.
  final List<_Shot> _photos = [];

  /// 고치기 모드에서 기존 기록을 한 번만 채우기 위한 표시.
  bool _loaded = false;

  /// 시안의 `PHOTOS · 1 / 5`. 서버 `CatchService.MAX_PHOTOS` 와 같은 값이다.
  static const _maxPhotos = 5;
  bool _submitting = false;
  DateTime _caughtAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    // 고치기 모드의 어종은 기록에서 온다 ([_fillOnce]).
    final id = widget.isEdit ? null : widget.initialSpeciesId;
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

  /// **길이는 빠졌다** (V11) — 시안의 라벨이 `길이 (선택)` 이고 서버도 null 을 받는다.
  ///
  /// 인증샷은 **새로 등록할 때만** 필수다 (기획서 3-3). 고치기에서까지 요구하면
  /// 사진 없이 남은 기록(시드·서버가 허용하는 사진 없는 등록)의 오타를 영영 못 고친다 —
  /// 사진을 붙이라고 강요하려고 저장을 막는 셈이 된다.
  bool get _ready =>
      _species != null && (widget.isEdit || _photos.isNotEmpty);

  /// 선택한 어종의 금지체장보다 작으면 안내 배너를 띄운다.
  /// **등록을 막지는 않는다** — 차단하면 사용자가 길이를 거짓으로 넣게 되고
  /// 데이터만 나빠진다 (기획서 5-4).
  bool get _underLegalSize {
    final min = _species?.minLegalSize;
    final len = _length;
    return min != null && len != null && len > 0 && len < min;
  }

  /// 고치기 화면은 기존 기록으로 시작한다. **한 번만** 채운다 —
  /// 다시 채우면 사용자가 고치던 값을 서버 값이 덮어쓴다 (`PostNewScreen` 과 같은 규칙).
  void _fillOnce(CatchRecord record) {
    if (_loaded) return;
    _loaded = true;
    _species = ref
        .read(speciesMasterProvider)
        .where((s) => s.id == record.speciesId)
        .firstOrNull;
    // 길이는 선택이라 없을 수 있다. 그때 `0` 을 넣으면 "0cm 를 쟀다" 가 된다.
    _lengthController.text = record.lengthCm?.toStringAsFixed(1) ?? '';
    _spotController.text = record.spotName;
    _memoController.text = record.memo;
    _caughtAt = record.caughtAt;
    _photos.addAll(record.photoUrls.map(_Kept.new));
  }

  /// 돌아갈 곳. 고치기는 왔던 어종 상세로, 새 기록은 도감으로.
  String get _backTo => _species == null
      ? '/collection'
      : '/collection/${_species!.id}';

  @override
  Widget build(BuildContext context) {
    if (widget.isEdit) {
      final existing = ref.watch(catchProvider(widget.catchId!));
      if (existing.hasError) {
        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 18),
              BackRow(label: '도감으로', onTap: () => context.go('/collection')),
              const Expanded(
                child: ErrorView(message: '기록을 불러오지 못했어요', height: 260),
              ),
            ],
          ),
        );
      }
      final record = existing.valueOrNull;
      if (record == null) {
        return const Center(child: CircularProgressIndicator());
      }
      _fillOnce(record);
    }

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          BackRow(
            label: widget.isEdit ? '기록으로' : '도감으로',
            onTap: () {
              if (_submitting) return;
              context.go(widget.isEdit ? _backTo : '/collection');
            },
          ),
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
                Reveal(
                  child: Text(
                    widget.isEdit ? '기록 수정' : '기록 추가',
                    style: AppText.screenTitle,
                  ),
                ),
                const SizedBox(height: 22),

                Reveal(
                  index: 1,
                  child: _SectionLabel(
                    '사진 · ${_photos.length} / $_maxPhotos',
                  ),
                ),
                const SizedBox(height: 10),
                Reveal(
                  index: 1,
                  child: _PhotoStrip(
                    photos: _photos,
                    max: _maxPhotos,
                    rare: _species?.rarity.isRare ?? false,
                    onAdd: _pickPhoto,
                    onRemove: (i) => setState(() => _photos.removeAt(i)),
                  ),
                ),
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
                    label: _submitting
                        ? '저장 중…'
                        : (widget.isEdit ? '수정 저장' : '기록 저장'),
                    icon: AppIcon.check,
                    onPressed: _ready && !_submitting ? _submit : null,
                  ),
                ),
                const SizedBox(height: 14),
                Reveal(
                  index: 5,
                  child: NoticeLine(
                    text: widget.isEdit
                        // 뺀 사진은 서버에서 파일까지 지운다 — 되돌릴 수 없다는 걸
                        // 저장 전에 말해 준다.
                        ? '뺀 사진은 저장할 때 완전히 지워집니다.'
                        : '기록은 내 도감에만 저장됩니다. 게시판 공개는 저장 후 따로 선택합니다.',
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
                  LineIcon(
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
            // 시안의 라벨 그대로. 안 적어도 저장된다 (V11) —
            // 놓아준 물고기나 사진만 남기고 싶은 기록이 있다.
            label: '길이 (선택)',
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
          // ⚠️ 힌트에 실제 포인트 이름(`기장 학리`)을 넣지 말 것. 오른쪽 정렬 회색 글씨라
          //    위의 `어종`·`일시` 행에 찍힌 **값과 똑같이 보인다** — 화살표도 없어서
          //    이미 채워진 칸으로 읽히고, 그대로 저장하면 안 가 본 곳이 기록에 남는다.
          //    등록된 51곳 밖에서도 낚을 수 있어 자유 입력인 건 의도한 설계다
          //    (`CatchRecord.spotName` 주석).
          _inputRow(
            label: '포인트',
            controller: _spotController,
            hint: '어디서 잡았나요?',
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
            LineIcon(
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
              Expanded(child: Text('메모', style: AppText.overline)),
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
    if (_photos.length >= _maxPhotos) {
      _toast('사진은 최대 $_maxPhotos장까지 올릴 수 있어요');
      return;
    }
    // 시트·크기 한도·권한 안내는 글쓰기 화면과 공유한다 (`pickPhotoFromSheet`).
    final picked = await pickPhotoFromSheet(context, ref, onMessage: _toast);
    if (picked == null || !mounted) return;
    setState(() => _photos.add(_Added(picked)));
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

  CatchDraft get _draft => CatchDraft(
    speciesId: _species!.id,
    lengthCm: _length,
    caughtAt: _caughtAt,
    // 새로 올릴 장만 파일로 간다. 이미 있는 장은 `keepPhotoUrls` 로 되돌려 보낸다.
    photos: [
      for (final shot in _photos)
        if (shot is _Added) shot.photo,
    ],
    spotName: _spotController.text.trim(),
    memo: _memoController.text.trim(),
  );

  Future<void> _submit() async {
    setState(() => _submitting = true);
    if (widget.isEdit) {
      await _saveEdit();
    } else {
      await _saveNew();
    }
  }

  Future<void> _saveNew() async {
    final result = await ref
        .read(fishingRepositoryProvider)
        .registerCatch(_draft);

    ref.read(collectionRevisionProvider.notifier).state++;
    if (!mounted) return;

    if (result.firstCatch) {
      // 도감 칸이 새로 채워졌으면 획득 연출로 넘어간다.
      context.go(
        '/catch/done/${result.record.speciesId}?catchId=${result.record.id}',
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('기록이 추가되었습니다')));
      context.go('/collection/${result.record.speciesId}');
    }
  }

  /// 고치기.
  ///
  /// ⚠️ **남길 장의 목록을 항상 보낸다.** 안 보내면 서버가 "사진을 건드리지 말라" 로
  /// 읽어서 화면에서 뺀 사진이 그대로 남는다 (계약서 3-7-3).
  ///
  /// 어종을 바꾸면 도감 칸도 달라진다 — 원래 어종의 마지막 기록이었다면 그 칸이 다시
  /// 잠기고 새 어종 칸이 열린다. 그래서 성공하면 **바뀐 어종의 상세**로 보낸다.
  Future<void> _saveEdit() async {
    final CatchRecord updated;
    try {
      updated = await ref
          .read(fishingRepositoryProvider)
          .updateCatch(
            widget.catchId!,
            _draft,
            keepPhotoUrls: [
              for (final shot in _photos)
                if (shot is _Kept) shot.url,
            ],
          );
    } on PostSubmitException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast(e.message);
      return;
    }

    ref.read(collectionRevisionProvider.notifier).state++;
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('기록을 수정했습니다')));
    context.go('/collection/${updated.speciesId}');
  }
}

/// 스트립의 한 칸. 이미 서버에 있는 장이거나, 방금 고른 장이다.
///
/// 등록에서는 [_Added] 만 나오고, 고치기에서는 둘이 섞인다. 서버가 "남긴 장 뒤에
/// 새 장" 순서를 강제하므로 이 목록도 **[_Kept] 가 앞, [_Added] 가 뒤**로 유지된다 —
/// 뒤에 더하고 빼기만 하면 저절로 지켜진다.
sealed class _Shot {
  const _Shot();
}

/// 서버에 이미 있는 장. 저장할 때 `keepPhotoUrls` 로 되돌려 보낸다.
class _Kept extends _Shot {
  const _Kept(this.url);

  final String url;
}

/// 방금 고른 장. 저장할 때 파일로 올라간다.
class _Added extends _Shot {
  const _Added(this.photo);

  final PickedPhoto photo;
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

/// ① 사진 — 상단 스트립. 필수. 고른 순서대로 늘어놓고 끝에 추가 칸을 둔다.
///
/// 첫 장이 **도감 칸의 표지**가 되므로 순서가 보이는 편이 낫다 — 격자로 흩어 두면
/// 어느 것이 대표인지 알 수 없다.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.photos,
    required this.max,
    required this.rare,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_Shot> photos;
  final int max;
  final bool rare;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  static const _tile = 96.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _tile,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        // 다 채우면 추가 칸을 빼서, 눌러도 안 되는 자리를 남기지 않는다.
        itemCount: photos.length + (photos.length < max ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => i < photos.length ? _thumb(i) : _addTile(),
      ),
    );
  }

  Widget _thumb(int index) {
    return SizedBox(
      width: _tile,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.thumb),
            child: switch (photos[index]) {
              // 방금 고른 장은 경로가 아니라 바이트로 그린다 — 웹에서도 같은 코드가
              // 돈다. 디코딩에 실패해도 화면이 깨지지 않게 줄무늬로 물러선다.
              _Added(:final photo) => Image.memory(
                photo.bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    PhotoPlaceholder(rare: rare, stripe: 5),
              ),
              // 이미 올라간 장은 인증이 필요한 주소라 [AuthedPhoto] 로 받아 온다
              // (`Image.network` 는 토큰을 안 붙여서 전부 깨진다).
              _Kept(:final url) => AuthedPhoto(
                path: url,
                rare: rare,
                stripe: 5,
                thumb: true,
              ),
            },
          ),
          if (index == 0)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.scrim,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                // 첫 장이 도감 표지가 된다는 걸 알려 준다.
                child: Text(
                  '대표',
                  style: AppText.badgeSmall.copyWith(color: AppColors.onAccent),
                ),
              ),
            ),
          Positioned(
            right: 4,
            top: 4,
            // x 아이콘뿐이라 읽어 줄 글자가 없다 — 스크린 리더에 이름을 준다.
            child: Semantics(
              label: '사진 빼기',
              button: true,
              child: PressScale(
                onTap: () => onRemove(index),
                scale: 0.86,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.scrim,
                    shape: BoxShape.circle,
                  ),
                  child: LineIcon(
                    AppIcon.close,
                    size: 13,
                    color: AppColors.onAccent,
                    stroke: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addTile() {
    return PressScale(
      onTap: onAdd,
      scale: 0.96,
      child: Container(
        width: _tile,
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(AppRadius.thumb),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LineIcon(
              AppIcon.camera,
              size: 22,
              color: AppColors.faint,
              stroke: 1.5,
            ),
            const SizedBox(height: 6),
            Text(
              photos.isEmpty ? '사진 추가' : '더 넣기',
              style: AppText.caption.copyWith(color: AppColors.label),
            ),
          ],
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
          Padding(
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
        decoration: BoxDecoration(
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
                        LineIcon(
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
