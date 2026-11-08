import 'package:flutter/material.dart';

import '../models/font_preferences.dart';

class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography(this.preferences);
  final FontPreferences preferences;
  static TextStyle codeStyle(BuildContext context) {
    final font =
        Theme.of(context).extension<AppTypography>()?.preferences ??
        const FontPreferences();
    return TextStyle(
      fontFamily: font.loadedFamily ?? 'monospace',
      fontFamilyFallback: const ['monospace'],
      fontWeight: font.weight,
      fontStyle: font.slant,
    );
  }

  static double columnWidth(BuildContext context, double fontSize) {
    var width = 0.0;
    for (final glyph in ['W', 'M', '0', '{', '漢', '😀']) {
      final painter = TextPainter(
        text: TextSpan(
          text: glyph,
          style: codeStyle(context).copyWith(fontSize: fontSize),
        ),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      if (painter.width > width) width = painter.width;
      painter.dispose();
    }
    return width;
  }

  @override
  AppTypography copyWith({FontPreferences? preferences}) =>
      AppTypography(preferences ?? this.preferences);
  @override
  AppTypography lerp(covariant AppTypography? other, double t) =>
      t < .5 ? this : other ?? this;
}
