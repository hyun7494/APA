import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 24x24 좌표계에 직접 그린 헤어라인 아이콘.
///
/// 시안 `Deep Tide Light.dc.html`의 SVG 심볼과 같은 패스를 쓴다. 이모지를
/// 쓰지 않는 이유는 OS마다 모양이 다르고 채도가 제멋대로라 화면 톤을
/// 무너뜨리기 때문이다.
///
/// 모든 획은 [LineIcon.stroke] 굵기로 렌더 크기와 무관하게 일정하게 보인다.
enum AppIcon {
  // 네비게이션
  home,
  wave,
  book,
  compass,
  chat,
  user,
  // 지표
  thermometer,
  swell,
  wind,
  sun,
  clock,
  sunrise,
  moon,
  // 조작
  pin,
  search,
  chevronRight,
  chevronLeft,
  arrowUpRight,
  plus,
  close,
  pencil,
  camera,
  check,
  trash,
  // 콘텐츠
  heart,
  bookmark,
  bell,
  logout,
  chart,
  fish,
  lock,
  ruler,
  trophy,
  medal,
  share,
  calendar,
  image,
  headset,
  settings,
  info,
}

/// 헤어라인 아이콘.
///
/// [size]는 렌더 박스 한 변, [stroke]는 논리 픽셀 기준 획 굵기다.
/// 크기를 키워도 획이 같이 굵어지지 않게 캔버스 배율의 역수를 곱해 보정한다.
class LineIcon extends StatelessWidget {
  const LineIcon(
    this.icon, {
    super.key,
    this.size = 20,
    this.color,
    this.stroke = 1.5,
  });

  final AppIcon icon;
  final double size;

  /// 생략하면 본문색. 팔레트가 바뀌면 값도 바뀌므로 기본 인자로는 못 준다.
  final Color? color;

  final double stroke;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _IconPainter(
          icon: icon,
          color: color ?? AppColors.body,
          stroke: stroke,
        ),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  const _IconPainter({
    required this.icon,
    required this.color,
    required this.stroke,
  });

  final AppIcon icon;
  final Color color;
  final double stroke;

  /// 모든 경로가 그려지는 기준 정사각 좌표계.
  static const _canvas = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _canvas;
    canvas.scale(scale);

    final line = Paint()
      ..style = PaintingStyle.stroke
      // 캔버스를 scale배 했으므로 획도 그만큼 굵어진다. 나눠서 상쇄한다.
      ..strokeWidth = stroke / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color
      ..isAntiAlias = true;

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..isAntiAlias = true;

    _draw(canvas, line, fill);
  }

  void _draw(Canvas canvas, Paint line, Paint fill) {
    switch (icon) {
      case AppIcon.home:
        canvas.drawPath(
          Path()
            ..moveTo(3.4, 10.2)
            ..lineTo(12, 3.2)
            ..lineTo(20.6, 10.2)
            ..lineTo(20.6, 19.4)
            ..cubicTo(20.6, 20.2, 19.9, 20.9, 19.1, 20.9)
            ..lineTo(4.9, 20.9)
            ..cubicTo(4.1, 20.9, 3.4, 20.2, 3.4, 19.4)
            ..close()
            ..moveTo(9.2, 20.9)
            ..lineTo(9.2, 13.6)
            ..lineTo(14.8, 13.6)
            ..lineTo(14.8, 20.9),
          line,
        );

      case AppIcon.wave:
        for (final y in const [9.0, 15.0]) {
          canvas.drawPath(_waveRow(y, 3.4), line);
        }

      case AppIcon.book:
        // 펼친 책 — 도감 탭
        canvas.drawPath(
          Path()
            ..moveTo(12, 6.6)
            ..cubicTo(10.4, 5, 8.2, 4.4, 4.6, 4.4)
            ..lineTo(4.6, 18.4)
            ..cubicTo(8.2, 18.4, 10.4, 19, 12, 20.6)
            ..cubicTo(13.6, 19, 15.8, 18.4, 19.4, 18.4)
            ..lineTo(19.4, 4.4)
            ..cubicTo(15.8, 4.4, 13.6, 5, 12, 6.6)
            ..close()
            ..moveTo(12, 6.6)
            ..lineTo(12, 20.6),
          line,
        );

      case AppIcon.compass:
        canvas.drawCircle(const Offset(12, 12), 9, line);
        canvas.drawPath(
          Path()
            ..moveTo(15.8, 8.2)
            ..lineTo(10.4, 10.4)
            ..lineTo(8.2, 15.8)
            ..lineTo(13.6, 13.6)
            ..close(),
          line,
        );

      case AppIcon.chat:
        canvas.drawPath(_bubble(), line);

      case AppIcon.user:
        canvas.drawCircle(const Offset(12, 8.4), 3.6, line);
        canvas.drawPath(
          Path()
            ..moveTo(4.6, 20.4)
            ..cubicTo(4.6, 16.2, 8.0, 14.4, 12, 14.4)
            ..cubicTo(16, 14.4, 19.4, 16.2, 19.4, 20.4),
          line,
        );

      case AppIcon.thermometer:
        canvas.drawPath(
          Path()
            ..moveTo(12, 4.6)
            ..lineTo(12, 14.2)
            ..moveTo(14.6, 7.6)
            ..lineTo(16.8, 7.6)
            ..moveTo(14.6, 11.0)
            ..lineTo(16.8, 11.0),
          line,
        );
        canvas.drawCircle(const Offset(12, 17.6), 3.4, line);

      case AppIcon.swell:
        canvas.drawPath(_waveRow(17.6, 2.8), line);
        canvas.drawPath(
          Path()
            ..moveTo(12, 4.2)
            ..lineTo(12, 13.0)
            ..moveTo(9.6, 10.8)
            ..lineTo(12, 13.0)
            ..lineTo(14.4, 10.8),
          line,
        );

      case AppIcon.wind:
        canvas.drawPath(
          Path()
            ..moveTo(2.6, 8.6)
            ..lineTo(12.6, 8.6)
            ..cubicTo(15.4, 8.6, 16.4, 5.4, 14.4, 4.2)
            ..cubicTo(13.4, 3.6, 12.4, 4.0, 12.0, 4.9)
            ..moveTo(2.6, 13.2)
            ..lineTo(16.4, 13.2)
            ..cubicTo(19.4, 13.2, 20.4, 16.6, 18.2, 17.8)
            ..cubicTo(17.1, 18.4, 16.1, 18.0, 15.7, 17.1)
            ..moveTo(2.6, 17.9)
            ..lineTo(9.8, 17.9),
          line,
        );

      case AppIcon.sun:
        canvas.drawCircle(const Offset(12, 12), 4.4, line);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          final dx = math.cos(a);
          final dy = math.sin(a);
          canvas.drawLine(
            Offset(12 + dx * 7.4, 12 + dy * 7.4),
            Offset(12 + dx * 9.8, 12 + dy * 9.8),
            line,
          );
        }

      case AppIcon.clock:
        canvas.drawCircle(const Offset(12, 12), 8.8, line);
        canvas.drawPath(
          Path()
            ..moveTo(12, 6.6)
            ..lineTo(12, 12.2)
            ..lineTo(16.0, 13.9),
          line,
        );

      case AppIcon.sunrise:
        canvas.drawPath(
          Path()
            ..moveTo(7.4, 15.2)
            ..arcToPoint(
              const Offset(16.6, 15.2),
              radius: const Radius.circular(4.6),
            ),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(2.6, 19.2)
            ..lineTo(21.4, 19.2)
            ..moveTo(12, 2.6)
            ..lineTo(12, 5.4)
            ..moveTo(4.6, 6.2)
            ..lineTo(6.4, 8.0)
            ..moveTo(19.4, 6.2)
            ..lineTo(17.6, 8.0),
          line,
        );

      case AppIcon.moon:
        canvas.drawPath(
          Path()
            ..moveTo(21, 12.79)
            ..arcToPoint(
              const Offset(11.21, 3),
              radius: const Radius.circular(9),
              largeArc: true,
            )
            ..arcToPoint(
              const Offset(21, 12.79),
              radius: const Radius.circular(7),
              clockwise: false,
            )
            ..close(),
          line,
        );

      case AppIcon.pin:
        canvas.drawPath(
          Path()
            ..moveTo(12, 21.4)
            ..cubicTo(12, 21.4, 19.6, 14.6, 19.6, 9.6)
            ..arcToPoint(
              const Offset(4.4, 9.6),
              radius: const Radius.circular(7.6),
              clockwise: false,
            )
            ..cubicTo(4.4, 14.6, 12, 21.4, 12, 21.4)
            ..close(),
          line,
        );
        canvas.drawCircle(const Offset(12, 9.6), 2.7, line);

      case AppIcon.search:
        canvas.drawCircle(const Offset(10.4, 10.4), 6.6, line);
        canvas.drawLine(
          const Offset(15.3, 15.3),
          const Offset(20.8, 20.8),
          line,
        );

      case AppIcon.chevronRight:
        canvas.drawPath(
          Path()
            ..moveTo(9.4, 5.6)
            ..lineTo(15.8, 12)
            ..lineTo(9.4, 18.4),
          line,
        );

      case AppIcon.chevronLeft:
        canvas.drawPath(
          Path()
            ..moveTo(14.6, 5.6)
            ..lineTo(8.2, 12)
            ..lineTo(14.6, 18.4),
          line,
        );

      case AppIcon.arrowUpRight:
        canvas.drawPath(
          Path()
            ..moveTo(7.4, 16.6)
            ..lineTo(16.6, 7.4)
            ..moveTo(9.8, 7.4)
            ..lineTo(16.6, 7.4)
            ..lineTo(16.6, 14.2),
          line,
        );

      case AppIcon.plus:
        canvas.drawPath(
          Path()
            ..moveTo(12, 5.4)
            ..lineTo(12, 18.6)
            ..moveTo(5.4, 12)
            ..lineTo(18.6, 12),
          line,
        );

      case AppIcon.pencil:
        canvas.drawPath(
          Path()
            ..moveTo(14.8, 4.6)
            ..lineTo(19.4, 9.2)
            ..lineTo(8.6, 20.0)
            ..lineTo(3.4, 21.2)
            ..lineTo(4.6, 16.0)
            ..close(),
          line,
        );
        canvas.drawLine(const Offset(13.0, 6.4), const Offset(17.6, 11.0), line);

      case AppIcon.camera:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2.8, 7, 18.4, 13.4),
            const Radius.circular(3.4),
          ),
          line,
        );
        canvas.drawCircle(const Offset(12, 13.7), 3.6, line);
        canvas.drawPath(
          Path()
            ..moveTo(9, 7)
            ..lineTo(10.4, 4.4)
            ..lineTo(13.6, 4.4)
            ..lineTo(15, 7),
          line,
        );

      case AppIcon.check:
        canvas.drawPath(
          Path()
            ..moveTo(4.8, 12.6)
            ..lineTo(9.6, 17.4)
            ..lineTo(19.2, 7.8),
          line..strokeWidth = line.strokeWidth * 1.3,
        );

      case AppIcon.trash:
        canvas.drawPath(
          Path()
            ..moveTo(4.8, 6.6)
            ..lineTo(19.2, 6.6)
            ..moveTo(9.6, 6.6)
            ..lineTo(9.6, 4.6)
            ..lineTo(14.4, 4.6)
            ..lineTo(14.4, 6.6)
            ..moveTo(6.6, 6.6)
            ..lineTo(7.6, 20.2)
            ..cubicTo(7.7, 21.0, 8.4, 21.6, 9.2, 21.6)
            ..lineTo(14.8, 21.6)
            ..cubicTo(15.6, 21.6, 16.3, 21.0, 16.4, 20.2)
            ..lineTo(17.4, 6.6)
            ..moveTo(10.2, 10.4)
            ..lineTo(10.2, 17.6)
            ..moveTo(13.8, 10.4)
            ..lineTo(13.8, 17.6),
          line,
        );

      case AppIcon.heart:
        canvas.drawPath(_heart(), line);

      case AppIcon.bookmark:
        canvas.drawPath(
          Path()
            ..moveTo(6.4, 3.6)
            ..lineTo(17.6, 3.6)
            ..lineTo(17.6, 20.8)
            ..lineTo(12, 16.4)
            ..lineTo(6.4, 20.8)
            ..close(),
          line,
        );

      case AppIcon.bell:
        canvas.drawPath(
          Path()
            ..moveTo(5.0, 18.0)
            ..cubicTo(6.4, 16.4, 6.9, 14.6, 6.9, 10.6)
            ..cubicTo(6.9, 7.2, 9.2, 4.6, 12, 4.6)
            ..cubicTo(14.8, 4.6, 17.1, 7.2, 17.1, 10.6)
            ..cubicTo(17.1, 14.6, 17.6, 16.4, 19.0, 18.0)
            ..close(),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(10.2, 20.2)
            ..cubicTo(10.6, 21.2, 11.2, 21.7, 12, 21.7)
            ..cubicTo(12.8, 21.7, 13.4, 21.2, 13.8, 20.2)
            ..moveTo(12, 2.4)
            ..lineTo(12, 4.6),
          line,
        );

      case AppIcon.logout:
        canvas.drawPath(
          Path()
            ..moveTo(13.6, 4.2)
            ..lineTo(6.2, 4.2)
            ..lineTo(6.2, 19.8)
            ..lineTo(13.6, 19.8)
            ..moveTo(10.8, 12)
            ..lineTo(20.4, 12)
            ..moveTo(17.2, 8.8)
            ..lineTo(20.4, 12)
            ..lineTo(17.2, 15.2),
          line,
        );

      case AppIcon.chart:
        for (final bar in const [
          [4.8, 13.6],
          [10.2, 8.8],
          [15.6, 4.6],
        ]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(bar[0], bar[1], 3.6, 19.4 - bar[1]),
              const Radius.circular(1.4),
            ),
            line,
          );
        }

      case AppIcon.fish:
        canvas.drawPath(
          Path()
            ..moveTo(2.6, 12)
            ..cubicTo(6.0, 6.4, 12.6, 5.4, 16.2, 8.2)
            ..cubicTo(17.6, 9.3, 18.4, 10.6, 18.8, 12)
            ..cubicTo(18.4, 13.4, 17.6, 14.7, 16.2, 15.8)
            ..cubicTo(12.6, 18.6, 6.0, 17.6, 2.6, 12)
            ..close()
            ..moveTo(18.8, 12)
            ..lineTo(21.6, 8.4)
            ..lineTo(21.6, 15.6)
            ..close(),
          line,
        );
        canvas.drawCircle(const Offset(7.2, 10.6), 0.95, fill);

      case AppIcon.lock:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4.8, 10.4, 14.4, 9.8),
            const Radius.circular(3),
          ),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8.4, 10.4)
            ..lineTo(8.4, 8.2)
            ..arcToPoint(
              const Offset(15.6, 8.2),
              radius: const Radius.circular(3.6),
            )
            ..lineTo(15.6, 10.4),
          line,
        );

      case AppIcon.ruler:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2.6, 8.6, 18.8, 6.8),
            const Radius.circular(2),
          ),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(7, 8.6)
            ..lineTo(7, 11)
            ..moveTo(11, 8.6)
            ..lineTo(11, 11)
            ..moveTo(15, 8.6)
            ..lineTo(15, 11)
            ..moveTo(19, 8.6)
            ..lineTo(19, 11),
          line,
        );

      case AppIcon.trophy:
        canvas.drawPath(
          Path()
            ..moveTo(7.6, 3.8)
            ..lineTo(16.4, 3.8)
            ..lineTo(16.4, 9.4)
            ..arcToPoint(
              const Offset(7.6, 9.4),
              radius: const Radius.circular(4.4),
            )
            ..close(),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(7.6, 5.4)
            ..lineTo(4.8, 5.4)
            ..lineTo(4.8, 7.2)
            ..arcToPoint(
              const Offset(7.9, 10.4),
              radius: const Radius.circular(3.2),
              clockwise: false,
            )
            ..moveTo(16.4, 5.4)
            ..lineTo(19.2, 5.4)
            ..lineTo(19.2, 7.2)
            ..arcToPoint(
              const Offset(16.1, 10.4),
              radius: const Radius.circular(3.2),
            )
            ..moveTo(12, 13.8)
            ..lineTo(12, 17.4)
            ..moveTo(8.4, 20.2)
            ..lineTo(15.6, 20.2),
          line,
        );

      case AppIcon.medal:
        // 도감 희귀 칸의 작은 원형 배지 안에 들어가므로 트로피보다 단순하게.
        canvas.drawCircle(const Offset(12, 14.6), 6.2, line);
        canvas.drawPath(
          Path()
            ..moveTo(8.2, 9.2)
            ..lineTo(6.2, 3.2)
            ..lineTo(12, 5.2)
            ..lineTo(17.8, 3.2)
            ..lineTo(15.8, 9.2),
          line,
        );

      case AppIcon.share:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3.6)
            ..lineTo(12, 15)
            ..moveTo(8.4, 7.2)
            ..lineTo(12, 3.6)
            ..lineTo(15.6, 7.2)
            ..moveTo(5, 13.4)
            ..lineTo(5, 19.4)
            ..cubicTo(5, 20.4, 5.8, 21.2, 6.8, 21.2)
            ..lineTo(17.2, 21.2)
            ..cubicTo(18.2, 21.2, 19, 20.4, 19, 19.4)
            ..lineTo(19, 13.4),
          line,
        );

      case AppIcon.calendar:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3.2, 5.2, 17.6, 15.6),
            const Radius.circular(3),
          ),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(3.2, 10)
            ..lineTo(20.8, 10)
            ..moveTo(8, 3.2)
            ..lineTo(8, 6.4)
            ..moveTo(16, 3.2)
            ..lineTo(16, 6.4),
          line,
        );

      case AppIcon.image:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3.0, 4.6, 18.0, 14.8),
            const Radius.circular(3.4),
          ),
          line,
        );
        canvas.drawCircle(const Offset(8.4, 9.8), 1.5, line);
        canvas.drawPath(
          Path()
            ..moveTo(4.0, 17.4)
            ..lineTo(9.2, 12.4)
            ..lineTo(14.0, 16.4)
            ..lineTo(16.6, 14.2)
            ..lineTo(20.4, 17.8),
          line,
        );

      case AppIcon.headset:
        canvas.drawPath(
          Path()
            ..moveTo(4.2, 15.0)
            ..cubicTo(4.2, 8.0, 7.8, 4.2, 12, 4.2)
            ..cubicTo(16.2, 4.2, 19.8, 8.0, 19.8, 15.0),
          line,
        );
        for (final x in const [2.4, 17.6]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 13.4, 4.0, 6.4),
              const Radius.circular(2.0),
            ),
            line,
          );
        }

      case AppIcon.close:
        // 두 획을 그대로 긋는다. `plus` 를 45도 돌려 쓰던 자리가 있었는데,
        // 같은 X 를 두 가지 방법으로 그리면 굵기·크기가 조금씩 어긋난다.
        canvas.drawPath(
          Path()
            ..moveTo(6.4, 6.4)
            ..lineTo(17.6, 17.6)
            ..moveTo(17.6, 6.4)
            ..lineTo(6.4, 17.6),
          line,
        );

      case AppIcon.settings:
        // 톱니바퀴 — 바깥 링 위에 톱니 8개, 가운데 축. 해(sun)도 방사선 8개를
        // 쓰지만 링이 없어서 작은 크기에서도 둘이 헷갈리지 않는다.
        canvas.drawCircle(const Offset(12, 12), 7.2, line);
        canvas.drawCircle(const Offset(12, 12), 3.0, line);
        for (var i = 0; i < 8; i++) {
          // 22.5도 비틀어 톱니가 축 십자와 겹치지 않게 한다.
          final a = i * math.pi / 4 + math.pi / 8;
          final dx = math.cos(a);
          final dy = math.sin(a);
          canvas.drawLine(
            Offset(12 + dx * 6.4, 12 + dy * 6.4),
            Offset(12 + dx * 9.6, 12 + dy * 9.6),
            line,
          );
        }

      case AppIcon.info:
        canvas.drawCircle(const Offset(12, 12), 9, line);
        canvas.drawLine(const Offset(12, 11.2), const Offset(12, 16.8), line);
        canvas.drawCircle(const Offset(12, 7.6), 0.95, fill);
    }
  }

  /// y를 기준선으로 진폭 [amp]의 물결 세 마루를 좌우 끝까지 그린다.
  static Path _waveRow(double y, double amp) {
    const start = 2.5;
    const span = 6.333;
    final p = Path()..moveTo(start, y);
    for (var i = 0; i < 3; i++) {
      final x0 = start + span * i;
      p.cubicTo(
        x0 + span * 0.33,
        y - amp,
        x0 + span * 0.67,
        y + amp,
        x0 + span,
        y,
      );
    }
    return p;
  }

  /// 꼬리까지 한 번에 이어 그린 말풍선 외곽선.
  static Path _bubble() {
    const r = Radius.circular(3.8);
    return Path()
      ..moveTo(6.6, 4.2)
      ..lineTo(17.4, 4.2)
      ..arcToPoint(const Offset(21.2, 8.0), radius: r)
      ..lineTo(21.2, 12.8)
      ..arcToPoint(const Offset(17.4, 16.6), radius: r)
      ..lineTo(12.8, 16.6)
      ..lineTo(8.4, 20.4)
      ..lineTo(8.4, 16.6)
      ..lineTo(6.6, 16.6)
      ..arcToPoint(const Offset(2.8, 12.8), radius: r)
      ..lineTo(2.8, 8.0)
      ..arcToPoint(const Offset(6.6, 4.2), radius: r)
      ..close();
  }

  static Path _heart() => Path()
    ..moveTo(12, 20.4)
    ..cubicTo(12, 20.4, 2.6, 14.6, 2.6, 8.9)
    ..cubicTo(2.6, 5.9, 5.0, 3.6, 7.9, 3.6)
    ..cubicTo(9.8, 3.6, 11.2, 4.6, 12, 5.9)
    ..cubicTo(12.8, 4.6, 14.2, 3.6, 16.1, 3.6)
    ..cubicTo(19.0, 3.6, 21.4, 5.9, 21.4, 8.9)
    ..cubicTo(21.4, 14.6, 12, 20.4, 12, 20.4)
    ..close();

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.color != color || old.stroke != stroke;
}
