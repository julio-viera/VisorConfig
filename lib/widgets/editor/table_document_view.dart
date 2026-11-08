import 'dart:convert';

import 'package:flutter/material.dart';

import '../../controllers/editor_document_controller.dart';
import '../../l10n/app_strings.dart';
import '../../models/config_format.dart';
import '../../models/json_document.dart';
import '../../utils/document_export.dart';

class TableDocumentView extends StatefulWidget {
  const TableDocumentView({
    super.key,
    required this.document,
    required this.language,
    required this.onEdit,
  });
  final EditorDocumentController document;
  final String language;
  final Future<void> Function(JsonNode) onEdit;
  @override
  State<TableDocumentView> createState() => _TableDocumentViewState();
}

class _TableDocumentViewState extends State<TableDocumentView> {
  String get languageCode => widget.language;
  bool get spanish => languageCode == 'es';
  String tr(String es, String en) => AppStrings(languageCode).tr(es, en);
  String? selectedTable;
  ParseResult? _tableResult;
  Map<String, List<String>> _tables = const {};
  List<JsonNode> _entries = const [];

  Widget _keyValueTable(ParseResult result) {
    final document = widget.document;
    final matches = document.matches.map((node) => node.path).toSet();
    return ListView.builder(
      controller: document.tableScroll,
      itemCount: _entries.length,
      itemExtent: 48,
      itemBuilder: (context, index) {
        final node = _entries[index];
        final label = node.parent == 0
            ? node.label
            : '${result.nodes[node.parent].label} / ${node.label}';
        return InkWell(
          onTap: () => widget.onEdit(node),
          child: Container(
            color: matches.contains(node.path)
                ? Theme.of(context).colorScheme.tertiaryContainer
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(node.preview, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.document;
    final result = d.result!;
    if (result.format.keyValue) {
      if (!identical(_tableResult, result)) {
        _entries = result.nodes.where((node) => !node.container).toList();
        _tables = const {};
        _tableResult = result;
      }
      return _keyValueTable(result);
    }
    if (!identical(_tableResult, result)) {
      _entries = const [];
      _tables = {
        for (final node in result.nodes) node.path: ?tableColumns(node.value),
      };
      _tableResult = result;
    }
    final tables = _tables;
    final rootMap =
        tables.isEmpty &&
        result.format != ConfigFormat.json &&
        result.value is Map &&
        (result.value as Map).isNotEmpty;
    if (tables.isEmpty && !rootMap) {
      return Center(
        child: Text(
          tr(
            'La tabla requiere un array de objetos uniformes.',
            'Table requires an array of uniform objects.',
          ),
        ),
      );
    }
    final table = rootMap
        ? r'$'
        : tables.containsKey(selectedTable)
        ? selectedTable!
        : tables.keys.first;
    final columns = rootMap
        ? (result.value as Map).keys.cast<String>().toList()
        : tables[table]!;
    final rowCount = rootMap ? 1 : (result.byPath[table]!.value as List).length;
    final matches = d.matches.map((n) => n.path).toSet();
    final content = LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: (columns.length * 200.0 + 60).clamp(
            constraints.maxWidth,
            double.infinity,
          ),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    const SizedBox(width: 60, child: Center(child: Text('#'))),
                    ...columns.map(
                      (c) => Expanded(
                        child: Text(
                          c,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: d.tableScroll,
                  itemExtent: 48,
                  itemCount: rowCount,
                  itemBuilder: (_, index) => Row(
                    children: [
                      SizedBox(width: 60, child: Center(child: Text('$index'))),
                      ...columns.map((key) {
                        final row = rootMap ? table : '$table[$index]';
                        final path = '$row[${jsonEncode(key)}]';
                        final n = d.result!.byPath[path]!;
                        return Expanded(
                          child: InkWell(
                            onTap: () => widget.onEdit(n),
                            child: Container(
                              height: 48,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              color: matches.contains(path)
                                  ? Theme.of(context)
                                        .colorScheme
                                        .tertiaryContainer
                                  : null,
                              child: Text(
                                n.preview,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (tables.length < 2) return content;
    return Column(
      children: [
        DropdownButton<String>(
          value: table,
          items: [
            for (final path in tables.keys)
              DropdownMenuItem(value: path, child: Text(path)),
          ],
          onChanged: (path) => setState(() => selectedTable = path),
        ),
        Expanded(child: content),
      ],
    );
  }
}
