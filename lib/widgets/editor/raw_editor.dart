import 'package:flutter/material.dart';

import '../../controllers/editor_document_controller.dart';
import '../../themes/app_typography.dart';
import '../../themes/code_palette.dart';
import '../../themes/editor_text_metrics.dart';

export '../../themes/editor_text_metrics.dart' show defaultEditorFontSize;

import 'dart:math' as math;

/// Long documents use a lazy, read-only list; structured editing stays available.
class RawEditor extends StatelessWidget {
  const RawEditor({
    super.key,
    required this.document,
    required this.hint,
    required this.largeNotice,
  });
  final EditorDocumentController document;
  final String hint, largeNotice;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: CodePalette.of(context).background,
    child: buildEditor(context),
  );

  Widget buildEditor(BuildContext context) {
    final palette = CodePalette.of(context);
    final errorLine = document.parseErrorLine;
    final text = document.editor.text;
    final scale =
        MediaQuery.textScalerOf(context).scale(defaultEditorFontSize) /
        defaultEditorFontSize;
    final metrics = EditorTextMetrics(context);
    final lineHeight = metrics.lineHeight;
    if (text.length > 1000000) {
      final segments = document.sourceSegments;
      return Column(
        children: [
          Padding(padding: const EdgeInsets.all(8), child: Text(largeNotice)),
          Expanded(
            child: ListView.builder(
              controller: document.rawScroll,
              itemExtent: lineHeight,
              itemCount: segments.length,
              itemBuilder: (_, index) {
                final highlighted = document.matches.any(
                  (m) =>
                      m.start <= segments[index].end &&
                      m.end >= segments[index].start,
                );
                return Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${segments[index].line}  ',
                        textAlign: TextAlign.right,
                        strutStyle: metrics.strut,
                        style: metrics.style.copyWith(
                          color: segments[index].line == errorLine
                              ? palette.error
                              : palette.muted,
                          fontWeight: segments[index].line == errorLine
                              ? FontWeight.bold
                              : FontWeight.normal,
                          backgroundColor: segments[index].line == errorLine
                              ? palette.errorBackground
                              : palette.gutter,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: highlighted
                            ? Theme.of(context).colorScheme.tertiaryContainer
                            : null,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            text.substring(
                              segments[index].start,
                              segments[index].end,
                            ),
                            strutStyle: metrics.strut,
                            style: metrics.style.copyWith(
                              color: palette.text,
                              fontSize: defaultEditorFontSize,
                              height: 1.65,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }
    final lines = document.lineMetrics;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 60,
            child: ClipRect(
              child: AnimatedBuilder(
                animation: document.rawScroll,
                builder: (context, _) => CustomPaint(
                  key: const Key('json-line-numbers'),
                  painter: LineNumbersPainter(
                    lines.count,
                    lineHeight,
                    document.rawScroll.hasClients
                        ? document.rawScroll.offset
                        : 0,
                    scale,
                    palette.muted,
                    errorLine: errorLine,
                    errorColor: palette.error,
                    errorBackground: palette.errorBackground,
                    background: palette.gutter,
                    codeStyle: metrics.style,
                    strut: metrics.strut,
                    textScaler: metrics.scaler,
                    firstBaseline: metrics.firstBaseline,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(
                  constraints.maxWidth - 60,
                  lines.longest *
                          AppTypography.columnWidth(
                            context,
                            defaultEditorFontSize,
                          ) +
                      48,
                ),
                height: constraints.maxHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    editorTopPadding,
                    24,
                    24,
                  ),
                  child: Stack(
                    children: [
                      TextField(
                        key: const Key('json-editor'),
                        controller: document.editor,
                        scrollController: document.rawScroll,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.multiline,
                        style: metrics.style.copyWith(color: palette.text),
                        strutStyle: metrics.strut,
                        decoration: null,
                      ),
                      if (text.isEmpty)
                        IgnorePointer(
                          child: Text(
                            hint,
                            style: metrics.style.copyWith(color: palette.muted),
                            strutStyle: metrics.strut,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LineNumbersPainter extends CustomPainter {
  LineNumbersPainter(
    this.count,
    this.lineHeight,
    this.offset,
    this.scale,
    this.color, {
    required this.errorLine,
    required this.errorColor,
    required this.errorBackground,
    required this.background,
    this.codeStyle = const TextStyle(fontFamily: 'monospace'),
    this.strut,
    this.textScaler = TextScaler.noScaling,
    this.firstBaseline = 0,
  });
  final TextStyle codeStyle;
  final StrutStyle? strut;
  final TextScaler textScaler;
  final double firstBaseline;
  final int count;
  final double lineHeight, offset, scale;
  final Color color, errorColor, errorBackground, background;
  final int? errorLine;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final first = math.max(
      0,
      ((offset - editorTopPadding) / lineHeight).floor(),
    );
    final last = math.min(count, first + (size.height / lineHeight).ceil() + 2);
    for (var i = first; i < last; i++) {
      final error = i + 1 == errorLine;
      final top = i * lineHeight + editorTopPadding - offset;
      if (error) {
        canvas.drawRect(
          Rect.fromLTWH(0, top, size.width, lineHeight),
          Paint()..color = errorBackground,
        );
        canvas.drawCircle(
          Offset(8, top + lineHeight / 2),
          3,
          Paint()..color = errorColor,
        );
      }
      final text = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: codeStyle.copyWith(
            fontSize: defaultEditorFontSize,
            height: 1.65,
            color: error ? errorColor : color,
            fontWeight: error ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        strutStyle: strut,
      )..layout();
      text.paint(
        canvas,
        Offset(
          size.width - text.width - 12,
          top + firstBaseline - text.computeLineMetrics().first.baseline,
        ),
      );
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant LineNumbersPainter oldDelegate) =>
      codeStyle != oldDelegate.codeStyle ||
      strut != oldDelegate.strut ||
      textScaler != oldDelegate.textScaler ||
      firstBaseline != oldDelegate.firstBaseline ||
      lineHeight != oldDelegate.lineHeight ||
      count != oldDelegate.count ||
      offset != oldDelegate.offset ||
      scale != oldDelegate.scale ||
      color != oldDelegate.color ||
      errorLine != oldDelegate.errorLine ||
      errorColor != oldDelegate.errorColor ||
      errorBackground != oldDelegate.errorBackground ||
      background != oldDelegate.background;
}
