import 'dart:ui' show BoxWidthStyle;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../controllers/editor_document_controller.dart';
import '../../models/config_format.dart';
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
    this.indentWithTabs = false,
    this.showWhitespace = false,
  });
  final EditorDocumentController document;
  final String hint, largeNotice;
  final bool indentWithTabs, showWhitespace;

  void insertIndentation({bool newline = false}) {
    final editor = document.editor;
    final value = editor.value;
    final selection = value.selection;
    if (!selection.isValid || selection.end > value.text.length) return;

    final isYaml = document.format == ConfigFormat.yaml;
    final useTabs = indentWithTabs && !isYaml;
    final unit = useTabs ? '\t' : '  ';
    var insertion = unit;
    var trailing = '';
    if (newline) {
      final start = selection.start;
      final lineStart = start == 0
          ? 0
          : value.text.lastIndexOf('\n', start - 1) + 1;
      final prefix = value.text.substring(lineStart, start);
      final leadingWhitespace = RegExp(r'^[ \t]*').stringMatch(prefix)!;
      final spaces = leadingWhitespace.replaceAll('\t', '  ');
      final indent = useTabs ? spaces.replaceAll('  ', '\t') : spaces;
      final betweenBraces =
          selection.isCollapsed &&
          prefix.endsWith('{') &&
          start < value.text.length &&
          value.text[start] == '}';
      final yamlMapping =
          isYaml &&
          RegExp(r'^(?!#).+:[ \t]*$').hasMatch(prefix.trimLeft()) &&
          (start == value.text.length || '\r\n'.contains(value.text[start]));
      insertion = betweenBraces || yamlMapping ? '\n$indent$unit' : '\n$indent';
      if (betweenBraces) {
        trailing = '\n${isYaml ? indent : leadingWhitespace}';
      }
    }
    editor.value = TextEditingValue(
      text: value.text.replaceRange(
        selection.start,
        selection.end,
        insertion + trailing,
      ),
      selection: TextSelection.collapsed(
        offset: selection.start + insertion.length,
      ),
    );
  }

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
                      lines.longest * metrics.style.letterSpacing! * scale +
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
                      CallbackShortcuts(
                        bindings: {
                          const SingleActivator(LogicalKeyboardKey.tab):
                              insertIndentation,
                          const SingleActivator(LogicalKeyboardKey.enter): () =>
                              insertIndentation(newline: true),
                          const SingleActivator(
                            LogicalKeyboardKey.numpadEnter,
                          ): () =>
                              insertIndentation(newline: true),
                        },
                        child: TextField(
                          key: const Key('json-editor'),
                          controller: document.editor,
                          // Whitespace markers need glyph bounds, without
                          // the extra box that fills the rest of a line.
                          selectionWidthStyle: showWhitespace
                              ? BoxWidthStyle.tight
                              : null,
                          inputFormatters: [
                            TextInputFormatter.withFunction((
                              oldValue,
                              newValue,
                            ) {
                              final selection = oldValue.selection;
                              if (!oldValue.composing.isCollapsed ||
                                  !newValue.composing.isCollapsed ||
                                  !selection.isValid ||
                                  !selection.isCollapsed ||
                                  selection.end > oldValue.text.length) {
                                return newValue;
                              }
                              final offset = selection.start;
                              if (newValue.selection !=
                                      TextSelection.collapsed(
                                        offset: offset + 1,
                                      ) ||
                                  newValue.text !=
                                      oldValue.text.replaceRange(
                                        offset,
                                        offset,
                                        '{',
                                      )) {
                                return newValue;
                              }
                              return newValue.copyWith(
                                text: newValue.text.replaceRange(
                                  offset + 1,
                                  offset + 1,
                                  '}',
                                ),
                              );
                            }),
                          ],
                          focusNode: document.rawFocus,
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
                      ),
                      if (showWhitespace)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Builder(
                              builder: (overlayContext) => CustomPaint(
                                painter: _WhitespacePainter(
                                  editorContext: context,
                                  overlayContext: overlayContext,
                                  document: document,
                                  color: palette.whitespace,
                                  metrics: metrics,
                                ),
                              ),
                            ),
                          ),
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

class _WhitespacePainter extends CustomPainter {
  _WhitespacePainter({
    required this.editorContext,
    required this.overlayContext,
    required this.metrics,
    required this.document,
    required this.color,
  }) : super(repaint: Listenable.merge([document.editor, document.rawScroll]));

  final BuildContext editorContext, overlayContext;
  final EditorTextMetrics metrics;
  final EditorDocumentController document;
  final Color color;
  static final _whitespace = RegExp(r'[ \t]');

  RenderEditable? _findEditable(RenderObject object) {
    if (object is RenderEditable) return object;
    RenderEditable? editable;
    object.visitChildren((child) {
      editable ??= _findEditable(child);
    });
    return editable;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final root = editorContext.findRenderObject();
    final overlay = overlayContext.findRenderObject();
    if (root == null || overlay is! RenderBox) return;
    final editable = _findEditable(root);
    if (editable == null || !editable.hasSize) return;

    final text = document.editor.text;
    final top = editable.localToGlobal(Offset.zero);
    final bottom = editable.localToGlobal(
      Offset(editable.size.width, editable.size.height),
    );
    final start = editable.getPositionForPoint(top).offset;
    final end = editable.getPositionForPoint(bottom).offset;
    // The layout may include composing text or be between editing updates.
    if (start < 0 || end <= start || end > text.length) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final origin = overlay.globalToLocal(top);
    canvas.translate(origin.dx, origin.dy);
    for (final match in _whitespace.allMatches(text.substring(start, end))) {
      final offset = start + match.start;
      final boxes = editable.getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + 1),
      );
      for (final box in boxes) {
        final rect = box.toRect();
        if (text[offset] == ' ') {
          canvas.drawCircle(rect.center, 1, paint);
        } else {
          final width = math.min(5.0, rect.width * .65);
          if (width <= 0) continue;
          final center = rect.center;
          final left = center.dx - width / 2;
          final right = center.dx + width / 2;
          final head = width / 3;
          canvas.drawLine(
            Offset(left, center.dy),
            Offset(right, center.dy),
            paint,
          );
          canvas.drawLine(
            Offset(right - head, center.dy - head),
            Offset(right, center.dy),
            paint,
          );
          canvas.drawLine(
            Offset(right - head, center.dy + head),
            Offset(right, center.dy),
            paint,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WhitespacePainter oldDelegate) =>
      oldDelegate.document != document ||
      oldDelegate.color != color ||
      oldDelegate.metrics.style != metrics.style ||
      oldDelegate.metrics.scaler != metrics.scaler;
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
