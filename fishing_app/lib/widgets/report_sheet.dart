import 'package:flutter/material.dart';

import '../models/report.dart';
import '../theme/app_theme.dart';
import 'app_buttons.dart';
import 'async_view.dart';
import 'press_scale.dart';

/// 신고 사유를 고르는 시트 (계약서 3-8).
///
/// [PhotoSourceSheet] 처럼 눌러서 바로 끝내지 않고 **고른 뒤 한 번 더 누르게** 한다.
/// 신고는 취소 버튼이 없는 동작이라 손가락이 미끄러진 것과 구분되어야 한다.
class ReportSheet extends StatefulWidget {
  const ReportSheet({super.key});

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

/// 시트가 돌려주는 값. 취소하면 null 이다.
typedef ReportDraft = ({ReportReason reason, String? detail});

class _ReportSheetState extends State<ReportSheet> {
  final _detail = TextEditingController();
  ReportReason? _reason;

  @override
  void initState() {
    super.initState();
    // `기타` 를 고른 뒤 글자를 채워야 버튼이 켜지므로 입력을 따라가야 한다.
    _detail.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  /// `기타` 는 설명이 있어야 보낼 수 있다 — 서버도 같은 규칙으로 400 을 낸다.
  /// 여기서 먼저 막는 이유는 왕복 한 번을 아끼려는 게 아니라, 버튼이 눌리는데
  /// 실패하는 것보다 눌리지 않는 편이 이유가 분명해서다.
  bool get _canSubmit {
    final reason = _reason;
    if (reason == null) return false;
    return !reason.needsDetail || _detail.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // 키보드가 올라오면 시트를 그만큼 밀어 올린다 — `기타` 입력이 가려진다.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.screen),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('이 글을 신고할까요?', style: AppText.sectionTitle),
              const SizedBox(height: 6),
              Text('어떤 점이 문제인지 골라 주세요.', style: AppText.caption),
              const SizedBox(height: 16),

              for (final reason in ReportReason.values)
                _ReasonRow(
                  reason: reason,
                  selected: _reason == reason,
                  onTap: () => setState(() => _reason = reason),
                ),

              if (_reason?.needsDetail == true) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.fill,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: TextField(
                    controller: _detail,
                    autofocus: true,
                    maxLines: 3,
                    minLines: 2,
                    // 서버 컬럼이 VARCHAR(300) 이다 (V12).
                    maxLength: 300,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    style: AppText.body.copyWith(color: AppColors.ink),
                    cursorColor: AppColors.accent,
                    decoration: InputDecoration(
                      hintText: '무엇이 문제인지 적어 주세요',
                      hintStyle: AppText.body.copyWith(color: AppColors.disabled),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 18),
              // 신고해도 글이 사라지지 않는다는 걸 미리 말해 둔다. 안 그러면 신고한
              // 사람은 글이 그대로인 것을 보고 신고가 안 됐다고 생각한다.
              const NoticeLine(text: '신고해도 글이 바로 내려가지는 않아요.'),
              const SizedBox(height: 16),

              PrimaryButton(
                label: '신고하기',
                color: AppColors.alert,
                onPressed: _canSubmit
                    ? () => Navigator.pop<ReportDraft>(context, (
                        reason: _reason!,
                        detail: _detail.text.trim().isEmpty
                            ? null
                            : _detail.text.trim(),
                      ))
                    : null,
              ),
              const SizedBox(height: 8),
              PressScale(
                onTap: () => Navigator.pop(context),
                scale: 0.98,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '취소',
                    textAlign: TextAlign.center,
                    style: AppText.rowValue.copyWith(color: AppColors.label),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final ReportReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.fill,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                reason.label,
                style: AppText.rowValue.copyWith(
                  color: selected ? AppColors.accentDark : AppColors.ink2,
                ),
              ),
            ),
            if (selected)
              LineIcon(
                AppIcon.check,
                size: 17,
                color: AppColors.accent,
                stroke: 2,
              ),
          ],
        ),
      ),
    );
  }
}

/// 시트를 띄우고 고른 사유를 받아 온다. 취소하면 null 이다.
Future<ReportDraft?> pickReportReason(BuildContext context) =>
    showModalBottomSheet<ReportDraft>(
      context: context,
      backgroundColor: Colors.transparent,
      // `기타` 입력이 키보드에 가리지 않게 시트가 화면 높이를 넘어설 수 있어야 한다.
      isScrollControlled: true,
      builder: (_) => const ReportSheet(),
    );
