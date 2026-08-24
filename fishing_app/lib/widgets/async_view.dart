import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_buttons.dart';

/// 로딩 — 도는 스피너 대신 들어올 내용의 뼈대를 미리 깔고 숨쉬게 한다.
class LoadingView extends StatefulWidget {
  const LoadingView({super.key, this.height = 120, this.lines = 3});

  final double height;

  /// 깔아둘 스켈레톤 줄 수
  final int lines;

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 1).animate(
          CurvedAnimation(parent: _controller, curve: AppMotion.state),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < widget.lines; i++) ...[
              if (i > 0) const SizedBox(height: 11),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                // 줄마다 길이를 달리해야 진짜 문단이 들어올 자리처럼 보인다
                widthFactor: switch (i % 3) {
                  0 => 0.92,
                  1 => 0.66,
                  _ => 0.78,
                },
                child: Container(
                  height: 13,
                  decoration: BoxDecoration(
                    color: AppColors.fill,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 실패·빈 상태.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.error,
    this.height = 140,
  });

  final String message;
  final Object? error;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LineIcon(
              AppIcon.info,
              size: 22,
              color: AppColors.faint,
              stroke: 1.4,
            ),
            const SizedBox(height: 12),
            Text(message, style: AppText.body, textAlign: TextAlign.center),
            if (error != null) ...[
              const SizedBox(height: 5),
              Text(
                '$error',
                style: AppText.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// 화면 상단 타이틀.
///
/// v2에서 위에 얹던 라틴 아이브로우("FIELD GUIDE")를 걷어냈다. 시안에는
/// 대문자 라틴 라벨이 한 곳도 남아 있지 않다 — 한글 타이틀 한 줄로 간다.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.actions = const []});

  final String title;

  /// 오른쪽에 붙는 버튼들
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Text(title, style: AppText.screenTitle)),
        for (final action in actions) ...[const SizedBox(width: 8), action],
      ],
    ),
  );
}

/// 섹션 구분 라벨.
///
/// 아이브로우 + 헤어라인 조합을 버리고 한글 제목만 남겼다. v2는 구획을
/// 선이 아니라 면과 여백으로 나눈다.
class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    required this.label,
    this.trailing,
    this.padded = true,
  });

  final String label;
  final Widget? trailing;

  /// false면 이미 좌우 여백이 잡힌 리스트 안에서 쓴다.
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Expanded(child: Text(label, style: AppText.sectionTitle)),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );

    if (!padded) return row;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: row,
    );
  }
}

/// 상세·검색 화면의 뒤로가기 줄.
class BackRow extends StatelessWidget {
  const BackRow({super.key, required this.label, required this.onTap, this.trailing});

  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
    child: Row(
      children: [
        IconTapButton(icon: AppIcon.chevronLeft, onPressed: onTap),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: AppText.rowLabel)),
        ?trailing,
      ],
    ),
  );
}

/// 안전 관련 오판을 막기 위한 고정 안내 문구.
///
/// 기획서 7장 — 낚시 지수 면책, 금지체장 안내 두 곳에서 쓴다.
class NoticeLine extends StatelessWidget {
  const NoticeLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 1),
          child: LineIcon(
            AppIcon.info,
            size: 14,
            color: AppColors.faint,
            stroke: 1.3,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppText.caption)),
      ],
    );
  }
}
