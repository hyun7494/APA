import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 사진이 들어갈 자리.
///
/// 실제 업로드가 붙기 전까지 대각 줄무늬로 표시한다. 사진 URL이 생기면
/// 이 위젯 자리에 이미지를 얹으면 된다.
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({super.key, this.rare = false, this.stripe = 8});

  /// 희귀 어종이면 골드 계열 줄무늬를 쓴다.
  final bool rare;

  /// 줄무늬 폭 — 큰 면일수록 넓게 준다.
  final double stripe;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _StripePainter(rare: rare, stripe: stripe));
}

/// 135° 방향 줄무늬.
class _StripePainter extends CustomPainter {
  const _StripePainter({required this.rare, required this.stripe});

  final bool rare;
  final double stripe;

  @override
  void paint(Canvas canvas, Size size) {
    final base = rare ? AppColors.photoGoldA : AppColors.photoA;
    final alt = rare ? AppColors.photoGoldB : AppColors.photoB;

    canvas.drawRect(Offset.zero & size, Paint()..color = base);

    final paint = Paint()
      ..color = alt
      ..style = PaintingStyle.stroke
      ..strokeWidth = stripe;

    final span = size.width + size.height;
    for (var d = -size.height; d < span; d += stripe * 2) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) =>
      old.rare != rare || old.stripe != stripe;
}

/// 사진 위에 얹는 반투명 카운트 배지 — "4회".
class PhotoCountBadge extends StatelessWidget {
  const PhotoCountBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.scrim,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppText.badgeSmall.copyWith(color: AppColors.onAccent),
      ),
    );
  }
}
