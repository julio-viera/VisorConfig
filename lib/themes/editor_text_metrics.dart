import 'package:flutter/material.dart';

import 'app_typography.dart';

const defaultEditorFontSize = 16.0;
const editorTopPadding = 24.0;

/// Uses the engine's font metrics, including rounding and scaling, for both lanes.
class EditorTextMetrics {
  EditorTextMetrics(BuildContext context)
    : style = AppTypography.codeStyle(context).copyWith(
        fontSize: defaultEditorFontSize,
        height: 1.65,
        leadingDistribution: TextLeadingDistribution.proportional,
        textBaseline: TextBaseline.alphabetic,
        letterSpacing: 0,
      ),
      scaler = MediaQuery.textScalerOf(context) {
    strut = StrutStyle.fromTextStyle(style, forceStrutHeight: true);
    final painter = TextPainter(
      text: TextSpan(text: '0\n0', style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      strutStyle: strut,
    )..layout();
    final lines = painter.computeLineMetrics();
    firstBaseline = lines.first.baseline;
    lineHeight = lines[1].baseline - lines[0].baseline;
    painter.dispose();
  }
  final TextStyle style;
  final TextScaler scaler;
  late final StrutStyle strut;
  late final double firstBaseline, lineHeight;
}
