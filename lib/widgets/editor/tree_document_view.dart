import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/editor_document_controller.dart';
import '../../l10n/app_strings.dart';
import '../../models/json_document.dart';
import '../../themes/app_typography.dart';

class TreeDocumentView extends StatefulWidget {
  const TreeDocumentView({
    super.key,
    required this.document,
    required this.language,
    required this.onEdit,
  });
  final EditorDocumentController document;
  final String language;
  final Future<void> Function(JsonNode) onEdit;
  @override
  State<TreeDocumentView> createState() => _TreeDocumentViewState();
}

class _TreeDocumentViewState extends State<TreeDocumentView> {
  String get languageCode => widget.language;
  bool get spanish => languageCode == 'es';
  String tr(String es, String en) => AppStrings(languageCode).tr(es, en);
  @override
  Widget build(BuildContext context) {
    final d = widget.document;
    final nodes = d.visible;
    final matches = d.matches.map((n) => n.path).toSet();
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => setState(() => d.expanded.clear()),
              child: Text(tr('Colapsar todo', 'Collapse all')),
            ),
            PopupMenuButton<int>(
              onSelected: (level) => setState(() {
                d.expanded.clear();
                d.expanded.addAll(
                  d.result!.nodes
                      .where((n) => n.depth < level)
                      .map((n) => n.path),
                );
              }),
              itemBuilder: (_) => [1, 2, 3, 5, 100]
                  .map(
                    (n) => PopupMenuItem(
                      value: n,
                      child: Text('${tr('Expandir nivel', 'Expand depth')} $n'),
                    ),
                  )
                  .toList(),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(tr('Expandir…', 'Expand…')),
              ),
            ),
          ],
        ),
        Expanded(
          child: ListView.builder(
            controller: d.scroll,
            itemExtent: 44,
            itemCount: nodes.length,
            itemBuilder: (_, i) {
              final n = nodes[i];
              return Container(
                color: matches.contains(n.path)
                    ? Theme.of(context).colorScheme.tertiaryContainer
                    : null,
                padding: EdgeInsets.only(
                  left: 12 + (n.depth * 20).clamp(0, 180).toDouble(),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: n.container
                          ? IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              onPressed: () => setState(() {
                                if (!d.expanded.remove(n.path)) {
                                  d.expanded.add(n.path);
                                }
                              }),
                              icon: Icon(
                                d.expanded.contains(n.path)
                                    ? Icons.expand_more
                                    : Icons.chevron_right,
                              ),
                            )
                          : const Icon(Icons.circle, size: 5),
                    ),
                    Expanded(
                      child: InkWell(
                        onDoubleTap: () => widget.onEdit(n),
                        child: Text(
                          '${n.label}   ${n.preview}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.codeStyle(context).copyWith(
                            color: n.container
                                ? null
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    Text(n.type, style: Theme.of(context).textTheme.labelSmall),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: tr('Editar', 'Edit'),
                      onPressed: () => widget.onEdit(n),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) => Clipboard.setData(
                        ClipboardData(
                          text: v == 'path' ? n.path : jsonEncode(n.value),
                        ),
                      ),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'path',
                          child: Text(tr('Copiar ruta', 'Copy path')),
                        ),
                        PopupMenuItem(
                          value: 'value',
                          child: Text(tr('Copiar valor', 'Copy value')),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
