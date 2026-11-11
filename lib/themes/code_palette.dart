import 'package:flutter/material.dart';

/// Opaque colors keep source text legible on editor and diff backgrounds.
class CodePalette extends ThemeExtension<CodePalette> {
  const CodePalette(this.dark, {this.variant = 'jade'});
  factory CodePalette.of(BuildContext context) =>
      Theme.of(context).extension<CodePalette>() ??
      CodePalette(Theme.of(context).brightness == Brightness.dark);
  final bool dark;
  final String variant;
  @override
  CodePalette copyWith({bool? dark, String? variant}) =>
      CodePalette(dark ?? this.dark, variant: variant ?? this.variant);
  @override
  CodePalette lerp(covariant CodePalette? other, double t) =>
      other == null || t < .5 ? this : other;
  static Color seed(String variant) => switch (variant) {
    'ocean' => const Color(0xff0369a1),
    'amethyst' => const Color(0xff7c3aed),
    'amber' => const Color(0xffa16207),
    'rose' => const Color(0xffbe185d),
    'slate' => const Color(0xff52657d),
    _ => const Color(0xff227c69),
  };
  Color get background => switch (variant) {
    'ocean' => dark ? const Color(0xff081c2c) : const Color(0xfff5faff),
    'amethyst' => dark ? const Color(0xff21172d) : const Color(0xfffcf8ff),
    'amber' => dark ? const Color(0xff241b12) : const Color(0xfffffbf0),
    'rose' => dark ? const Color(0xff291721) : const Color(0xfffff7fa),
    'slate' => dark ? const Color(0xff15191f) : const Color(0xfff8fafc),
    _ => dark ? const Color(0xff111827) : Colors.white,
  };
  Color get text => dark ? const Color(0xfff3f4f6) : const Color(0xff172033);
  Color get muted => dark ? const Color(0xffcbd5e1) : const Color(0xff475569);
  Color get gutter => Color.alphaBlend(
    (dark ? Colors.white : seed(variant)).withValues(alpha: dark ? .045 : .07),
    background,
  );
  Color get key => dark ? const Color(0xff93c5fd) : const Color(0xff174ea6);
  Color get string => dark ? const Color(0xffa7f3d0) : const Color(0xff116149);
  Color get number => dark ? const Color(0xfffcd34d) : const Color(0xff854300);
  Color get literal => dark ? const Color(0xffc4b5fd) : const Color(0xff5b21b6);
  Color get comment => dark ? const Color(0xffa5b4c7) : const Color(0xff526078);
  Color get section => dark ? const Color(0xff67e8f9) : const Color(0xff0e6175);
  Color get directive =>
      dark ? const Color(0xfff9a8d4) : const Color(0xff9d174d);
  Color get nullLiteral =>
      dark ? const Color(0xfffdba74) : const Color(0xff9a3412);
  Color get error => dark ? const Color(0xffff8a8a) : const Color(0xffb91c1c);
  Color get errorBackground =>
      dark ? const Color(0xff4c1820) : const Color(0xfffee2e2);
  Color get selectedTab => switch (variant) {
    'ocean' => const Color(0xff0369a1),
    'amethyst' => const Color(0xff6d28d9),
    'amber' => const Color(0xff92400e),
    'rose' => const Color(0xff9d174d),
    'slate' => const Color(0xff52657d),
    _ => dark ? const Color(0xff2563eb) : const Color(0xff164e63),
  };
  Color get inactiveTab =>
      dark ? const Color(0xff1e293b) : const Color(0xffe2e8f0);
  Color get inactiveTabText =>
      dark ? const Color(0xffcbd5e1) : const Color(0xff334155);
}
