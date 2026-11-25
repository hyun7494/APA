import 'package:fishing_app/models/rating.dart';
import 'package:fishing_app/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 대비. 글자는 놓이는 면 위에서 4.5:1 이상이어야 한다.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + .05 : lb + .05) / (la > lb ? lb + .05 : la + .05);
}

void main() {
  for (final p in [AppPalette.light, AppPalette.dark]) {
    final mode = p.isDark ? '다크' : '라이트';

    test('$mode: 글자색은 카드·배경 위에서 4.5:1 이상', () {
      final texts = {
        'ink2': p.ink2, 'body': p.body, 'sub': p.sub, 'label': p.label,
        'muted': p.muted, 'faint': p.faint, 'accent': p.accent,
        'accentDark': p.accentDark, 'goldText': p.goldText,
      };
      for (final MapEntry(:key, :value) in texts.entries) {
        for (final bg in [p.surface, p.bg]) {
          expect(contrast(value, bg), greaterThanOrEqualTo(4.5),
              reason: '$key on $bg');
        }
      }
      expect(contrast(p.goldText, p.goldSoft), greaterThanOrEqualTo(4.5));
      expect(contrast(p.accentDark, p.accentSoft), greaterThanOrEqualTo(4.5));
    });

    test('$mode: 주색·강조색 면 위 글자', () {
      expect(contrast(p.onAccent, p.emphasis), greaterThanOrEqualTo(4.5));
      expect(contrast(p.onAccent, p.accent), greaterThanOrEqualTo(4.5));
    });
  }

  test('등급 배지 글자는 배지 면 위에서 4.5:1 이상', () {
    for (final r in Rating.values) {
      expect(contrast(r.lightForeground, r.lightBackground),
          greaterThanOrEqualTo(4.5), reason: '${r.code} 라이트');
      expect(contrast(r.darkForeground, r.darkBackground),
          greaterThanOrEqualTo(4.5), reason: '${r.code} 다크');
    }
  });
}
