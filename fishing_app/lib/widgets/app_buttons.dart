import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'press_scale.dart';

/// 주 버튼 — 잉크색 사각 버튼.
///
/// 시안은 알약이 아니라 라운드 사각(r10~14)을 쓰고, 안쪽에 아이콘 껍데기를
/// 두지 않는다. 라벨만 가운데 두는 국내 앱 문법이다.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 54,
    this.color,
    this.radius = 14,
  });

  final String label;
  final VoidCallback? onPressed;

  /// 라벨 왼쪽에 붙는 아이콘 (선택)
  final AppIcon? icon;

  final double height;

  /// 생략하면 강조색 면.
  final Color? color;

  final double radius;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final icon = this.icon;
    final color = this.color ?? AppColors.emphasis;

    return PressScale(
      onTap: onPressed,
      scale: 0.98,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                LineIcon(
                  icon,
                  size: 18,
                  color: AppColors.onAccent,
                  stroke: 1.7,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  style: AppText.rowValue.copyWith(
                    color: AppColors.onAccent,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 보조 버튼 — 회색 면.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 54,
    this.radius = 14,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppIcon? icon;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;

    return PressScale(
      onTap: onPressed,
      scale: 0.98,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              LineIcon(icon, size: 18, color: AppColors.sub, stroke: 1.7),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                style: AppText.rowValue.copyWith(
                  color: AppColors.sub,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 헤더 오른쪽의 작은 사각 버튼 — "기록", "임시저장".
class HeaderButton extends StatelessWidget {
  const HeaderButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final AppIcon? icon;

  /// true면 잉크색으로 채운다.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    final fg = filled ? AppColors.onAccent : AppColors.sub;

    return PressScale(
      onTap: onPressed,
      scale: 0.94,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: filled ? AppColors.emphasis : AppColors.fill,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              LineIcon(icon, size: 16, color: fg, stroke: 1.7),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppText.tileName.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// 헤더의 아이콘 전용 버튼 — 검색, 알림, 뒤로.
///
/// 시안은 원형 배경 없이 아이콘만 둔다(사진 위에 얹을 때만 흰 원을 깐다).
class IconTapButton extends StatelessWidget {
  const IconTapButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size = 21,
    this.badge = false,
    this.onPhoto = false,
  });

  final AppIcon icon;
  final VoidCallback onPressed;

  /// 생략하면 소제목색.
  final Color? color;

  final double size;

  /// 오른쪽 위 알림 점
  final bool badge;

  /// 사진 위에 얹는 경우 흰 원형 배경을 깐다.
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onPressed,
      scale: 0.88,
      child: Container(
        width: 38,
        height: 38,
        decoration: onPhoto
            ? BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface.withValues(alpha: 0.9),
              )
            : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            LineIcon(
              icon,
              size: size,
              color: color ?? AppColors.ink2,
              stroke: 1.6,
            ),
            if (badge)
              Positioned(
                top: 8,
                right: 9,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.alert,
                    border: Border.all(color: AppColors.bg, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 스크롤과 무관하게 항상 같은 자리에 있는 하단 고정 CTA 바.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child, this.note});

  final Widget child;

  /// 버튼 위에 한 줄로 붙는 안내 문구
  final String? note;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    final inset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        12,
        AppSpacing.screen,
        inset > 0 ? inset : 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.bottomBar,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (note != null) ...[
            Text(note, style: AppText.caption, textAlign: TextAlign.center),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}
