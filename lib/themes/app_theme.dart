import 'package:flutter/material.dart';

import '../models/font_preferences.dart';
import 'app_typography.dart';
import 'code_palette.dart';

ThemeData buildAppTheme(
  Brightness brightness,
  String colorTheme, [
  FontPreferences font = const FontPreferences(),
]) {
  final palette = CodePalette(
    brightness == Brightness.dark,
    variant: colorTheme,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: CodePalette.seed(colorTheme),
      brightness: brightness,
    ),
    scaffoldBackgroundColor: palette.background,
    fontFamily: font.loadedFamily,
    extensions: [palette, AppTypography(font)],
  );
  TextStyle? apply(TextStyle? style) => style?.copyWith(
    fontWeight: font.weight == FontWeight.bold
        ? FontWeight.bold
        : style.fontWeight,
    fontStyle: font.slant,
  );
  final text = base.textTheme;
  return base.copyWith(
    textTheme: TextTheme(
      displayLarge: apply(text.displayLarge),
      displayMedium: apply(text.displayMedium),
      displaySmall: apply(text.displaySmall),
      headlineLarge: apply(text.headlineLarge),
      headlineMedium: apply(text.headlineMedium),
      headlineSmall: apply(text.headlineSmall),
      titleLarge: apply(text.titleLarge),
      titleMedium: apply(text.titleMedium),
      titleSmall: apply(text.titleSmall),
      bodyLarge: apply(text.bodyLarge),
      bodyMedium: apply(text.bodyMedium),
      bodySmall: apply(text.bodySmall),
      labelLarge: apply(text.labelLarge),
      labelMedium: apply(text.labelMedium),
      labelSmall: apply(text.labelSmall),
    ),
  );
}
