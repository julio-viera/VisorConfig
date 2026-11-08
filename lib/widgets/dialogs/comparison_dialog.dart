import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../themes/app_typography.dart';
import '../../themes/code_palette.dart';
import '../../utils/line_diff.dart';

import 'dart:math' as math;

class ComparisonSource {
  const ComparisonSource(this.name, this.text);
  final String name, text;
}

class ComparisonDialog extends StatefulWidget {
  const ComparisonDialog({
    super.key,
    required this.left,
    required this.others,
    required this.spanish,
    this.language,
  });
  final ComparisonSource left;
  final List<ComparisonSource> others;
  final bool spanish;
  final String? language;
  @override
  State<ComparisonDialog> createState() => _ComparisonDialogState();
}

class _ComparisonDialogState extends State<ComparisonDialog> {
  int right = 0;
  int currentDifference = -1;
  late Future<List<DiffRow>> comparison;
  final leftScroll = ScrollController(), rightScroll = ScrollController();
  bool syncing = false;
  String tr(String es, String en) =>
      AppStrings(widget.language ?? (widget.spanish ? 'es' : 'en')).tr(es, en);
  @override
  void initState() {
    super.initState();
    load();
    leftScroll.addListener(() => sync(leftScroll, rightScroll));
    rightScroll.addListener(() => sync(rightScroll, leftScroll));
  }

  void sync(ScrollController from, ScrollController to) {
    if (syncing || !from.hasClients || !to.hasClients) return;
    syncing = true;
    to.jumpTo(from.offset.clamp(0, to.position.maxScrollExtent));
    syncing = false;
  }

  void load() {
    currentDifference = -1;
    comparison = compute(compareLines, [
      widget.left.text,
      widget.others[right].text,
    ]);
  }

  void navigateDifference(List<int> differences, int direction) {
    if (differences.isEmpty || !leftScroll.hasClients) return;
    setState(
      () => currentDifference = currentDifference < 0
          ? (direction > 0 ? 0 : differences.length - 1)
          : (currentDifference + direction) % differences.length,
    );
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    final target =
        (differences[currentDifference] * 30 * scale -
                leftScroll.position.viewportDimension / 3)
            .clamp(0, leftScroll.position.maxScrollExtent);
    leftScroll.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    leftScroll.dispose();
    rightScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(20),
    child: SizedBox(
      width: MediaQuery.sizeOf(context).width,
      height: MediaQuery.sizeOf(context).height * .85,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<DiffRow>>(
          future: comparison,
          builder: (context, snapshot) {
            final ready =
                snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasError;
            final rows = ready ? snapshot.data! : <DiffRow>[];
            final differences = <int>[];
            var changes = 0;
            for (var i = 0; i < rows.length; i++) {
              if (rows[i].changed) {
                changes++;
                if (i == 0 || !rows[i - 1].changed) differences.add(i);
              }
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('Comparar documentos', 'Compare documents'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: tr('Cerrar', 'Close'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                SizedBox(
                  key: const Key('diff-navigation-bar'),
                  height: 40,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          !ready
                              ? tr('Comparando…', 'Comparing…')
                              : changes == 0
                              ? tr(
                                  'Sin diferencias de texto',
                                  'No text differences',
                                )
                              : '$changes ${tr('filas con diferencias', 'rows with differences')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (differences.isNotEmpty) ...[
                        IconButton(
                          key: const Key('diff-previous'),
                          tooltip: tr(
                            'Diferencia anterior',
                            'Previous difference',
                          ),
                          onPressed: () => navigateDifference(differences, -1),
                          icon: const Icon(Icons.keyboard_arrow_up),
                        ),
                        Text(
                          '${currentDifference < 0 ? '—' : currentDifference + 1}/${differences.length}',
                          key: const Key('diff-position'),
                        ),
                        IconButton(
                          key: const Key('diff-next'),
                          tooltip: tr(
                            'Diferencia siguiente',
                            'Next difference',
                          ),
                          onPressed: () => navigateDifference(differences, 1),
                          icon: const Icon(Icons.keyboard_arrow_down),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  key: const Key('diff-file-names'),
                  children: [
                    Expanded(
                      child: Text(
                        widget.left.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: right,
                        items: List.generate(
                          widget.others.length,
                          (i) => DropdownMenuItem(
                            value: i,
                            child: Text(
                              widget.others[i].name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        onChanged: (v) => setState(() {
                          right = v!;
                          load();
                        }),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 1),
                Expanded(
                  child: !ready
                      ? Center(
                          child: snapshot.hasError
                              ? Text('${snapshot.error}')
                              : const CircularProgressIndicator(),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: pane(rows, true, leftScroll)),
                            const VerticalDivider(width: 1),
                            Expanded(child: pane(rows, false, rightScroll)),
                          ],
                        ),
                ),
                Container(
                  key: const Key('diff-legend-bar'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Wrap(
                    spacing: 20,
                    children: [
                      Text(
                        '− ${tr('Eliminado / anterior', 'Removed / before')}',
                        style: AppTypography.codeStyle(context)
                            .copyWith(color: CodePalette.of(context).error),
                      ),
                      Text(
                        '+ ${tr('Agregado / nuevo', 'Added / after')}',
                        style: AppTypography.codeStyle(context).copyWith(
                          color: CodePalette.of(context).dark
                              ? const Color(0xff86efac)
                              : const Color(0xff116149),
                        ),
                      ),
                      Text(
                        tr(
                          'Líneas del texto original',
                          'Original source line numbers',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
  Widget pane(
    List<DiffRow> rows,
    bool left,
    ScrollController vertical,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
      final longest = rows.fold<int>(
        0,
        (length, row) =>
            math.max(length, (left ? row.left : row.right)?.length ?? 0),
      );
      final width = math.max(
        constraints.maxWidth,
        longest * AppTypography.columnWidth(context, 14) + 88,
      );
      final palette = CodePalette.of(context);
      final dark = palette.dark;
      return ColoredBox(
        color: palette.background,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: Scrollbar(
              controller: vertical,
              thumbVisibility: true,
              child: ListView.builder(
                key: Key(left ? 'diff-left' : 'diff-right'),
                controller: vertical,
                itemExtent: 30 * scale,
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final row = rows[i];
                  final text = left ? row.left : row.right;
                  final number = left ? row.leftNumber : row.rightNumber;
                  final highlight = row.changed && text != null;
                  final background = highlight
                      ? (left
                            ? (dark
                                  ? const Color(0xff572a30)
                                  : const Color(0xffffe4e6))
                            : (dark
                                  ? const Color(0xff1c4936)
                                  : const Color(0xffdcfce7)))
                      : null;
                  return Container(
                    key: ValueKey(
                      '${left ? 'left' : 'right'}-line-${number ?? 'blank-$i'}',
                    ),
                    color: background,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 52,
                          child: Text(
                            number?.toString() ?? '',
                            textAlign: TextAlign.right,
                            style: AppTypography.codeStyle(context)
                                .copyWith(color: palette.muted, fontSize: 12),
                          ),
                        ),
                        SizedBox(
                          width: 24,
                          child: Text(
                            highlight ? (left ? '−' : '+') : '',
                            style: AppTypography.codeStyle(context).copyWith(
                              color: palette.text,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          child: SelectableText(
                            text ?? '',
                            maxLines: 1,
                            style: AppTypography.codeStyle(context)
                                .copyWith(color: palette.text, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}
