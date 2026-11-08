import '../../models/config_format.dart';
import '../../models/json_standard.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/editor_document_controller.dart';
import '../../l10n/app_strings.dart';
import '../../utils/document_export.dart';
import '../../services/key_value_config.dart';

class DocumentToolbar extends StatelessWidget {
  const DocumentToolbar({
    super.key,
    required this.document,
    required this.language,
    required this.onOpen,
    required this.onSave,
    required this.onSaveAs,
    required this.onSchema,
    required this.onExport,
    required this.onNavigateMatch,
    required this.onChanged,
  });
  final EditorDocumentController document;
  final String language;
  final VoidCallback onOpen, onSave, onSaveAs, onSchema, onChanged;
  final ValueChanged<String> onExport;
  final ValueChanged<int> onNavigateMatch;
  EditorDocumentController get d => document;
  String tr(String es, String en) => AppStrings(language).tr(es, en);
  void changeView(VoidCallback change) {
    change();
    onChanged();
  }

  Widget action(IconData icon, String title, VoidCallback callback) =>
      IconButton(
        tooltip: title,
        onPressed: callback,
        icon: Icon(icon, size: 20),
      );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final valid =
          d.result != null &&
          d.result!.error == null &&
          !d.result!.hasDuplicateKeys;
      Widget button(IconData icon, String label, VoidCallback? callback) =>
          IconButton(
            tooltip: label,
            onPressed: callback,
            icon: Icon(icon, size: 20),
          );
      return Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Wrap(
          key: const Key('document-toolbar'),
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            action(
              Icons.folder_open,
              tr('Abrir · Ctrl+O', 'Open · Ctrl+O'),
              onOpen,
            ),
            action(
              Icons.save_outlined,
              tr('Guardar · Ctrl+S', 'Save · Ctrl+S'),
              onSave,
            ),
            action(
              Icons.save_as_outlined,
              tr('Guardar como · Ctrl+Shift+S', 'Save as · Ctrl+Shift+S'),
              onSaveAs,
            ),
            ...[
              ('raw', Icons.code, tr('Texto', 'Raw')),
              ('tree', Icons.account_tree_outlined, tr('Árbol', 'Tree')),
              ('diagram', Icons.schema_outlined, tr('Diagrama', 'Diagram')),
              ('graph', Icons.hub_outlined, tr('Grafo', 'Graph')),
              (
                'radial',
                Icons.bubble_chart_outlined,
                tr('Grafo radial', 'Radial graph'),
              ),
              ('table', Icons.table_chart_outlined, tr('Tabla', 'Table')),
            ].map(
              (view) => IconButton.filledTonal(
                tooltip: view.$3,
                icon: Icon(view.$2, size: 20),
                isSelected: d.mode == view.$1,
                style: IconButton.styleFrom(
                  backgroundColor: d.mode == view.$1
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                  foregroundColor: d.mode == view.$1
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: () => changeView(() => d.mode = view.$1),
              ),
            ),
            SizedBox(
              width: (constraints.maxWidth - 16).clamp(0, 340),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('document-search'),
                        controller: d.search,
                        onChanged: (_) {
                          d.currentMatch = 0;
                          d.updateSearch();
                        },
                        onSubmitted: (_) => onNavigateMatch(1),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 28,
                          ),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          hintText: d.jsonPath
                              ? r'$.store.book[*]'
                              : tr('Buscar…', 'Search…'),
                          border: InputBorder.none,
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          errorText: d.searchError == null
                              ? null
                              : tr('JSONPath inválido', 'Invalid JSONPath'),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: tr(
                        'Buscar con JSONPath',
                        'Search with JSONPath',
                      ),
                      isSelected: d.jsonPath,
                      icon: const Icon(Icons.manage_search, size: 20),
                      selectedIcon: const Icon(Icons.manage_search, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: d.jsonPath
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.transparent,
                      ),
                      onPressed: () {
                        d.jsonPath = !d.jsonPath;
                        d.updateSearch();
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '${d.matches.isEmpty ? 0 : d.currentMatch + 1}/${d.matches.length}${d.searchTruncated ? '+' : ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: button(
                        Icons.keyboard_arrow_up,
                        tr('Anterior', 'Previous'),
                        d.matches.isEmpty ? null : () => onNavigateMatch(-1),
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: button(
                        Icons.keyboard_arrow_down,
                        tr('Siguiente', 'Next'),
                        d.matches.isEmpty ? null : () => onNavigateMatch(1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            button(
              Icons.format_align_left,
              tr('Formatear', 'Format'),
              valid
                  ? () async {
                      final result = d.result!;
                      final format = result.format;
                      if (format == ConfigFormat.json) {
                        d.editor.text = const JsonEncoder.withIndent('  ')
                            .convert(result.value);
                        return;
                      }
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(tr('Formatear', 'Format')),
                          content: Text(
                            tr(
                              'Se volverá a generar el texto. Se perderán los comentarios y se expandirán los alias.',
                              'The text will be regenerated. Comments will be removed and aliases expanded.',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(tr('Cancelar', 'Cancel')),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(tr('Formatear', 'Format')),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || d.closed || d.result != result) {
                        return;
                      }
                      if (format == ConfigFormat.toml) {
                        d.editor.text = toToml(result.nativeValue);
                      } else if (format.keyValue) {
                        d.formatOverride ??= format;
                        d.editor.text = encodeKeyValueConfig(
                          result.value,
                          format,
                        );
                      } else {
                        final yaml = toYaml(result.nativeValue);
                        d.editor.text = ConfigFormat.detect(yaml) == format
                            ? yaml
                            : '---\n$yaml';
                      }
                    }
                  : null,
            ),
            button(
              Icons.compress,
              tr('Minificar', 'Minify'),
              valid && d.format == ConfigFormat.json
                  ? () => d.editor.text = jsonEncode(d.result!.value)
                  : null,
            ),
            button(Icons.content_paste, tr('Pegar', 'Paste'), () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (!d.closed && data?.text != null) d.editor.text = data!.text!;
            }),
            button(Icons.copy, tr('Copiar', 'Copy'), () async {
              await Clipboard.setData(ClipboardData(text: d.editor.text));
            }),
            PopupMenuButton<String>(
              tooltip: '${tr('Formato', 'Document format')}: ${d.format.label}',
              icon: const Icon(Icons.verified_outlined, size: 20),
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: 'auto',
                  checked: d.formatOverride == null,
                  child: Text(tr('Detectar formato', 'Detect format')),
                ),
                for (final format in ConfigFormat.values)
                  CheckedPopupMenuItem(
                    value: format.name,
                    checked: d.formatOverride == format,
                    child: Text(format.label),
                  ),
                if (d.format == ConfigFormat.json) ...[
                  const PopupMenuDivider(),
                  for (final standard in jsonStandards)
                    CheckedPopupMenuItem(
                      value: standard,
                      checked: d.standard == standard,
                      child: Text(standard),
                    ),
                ],
              ],
              onSelected: (value) {
                if (jsonStandards.contains(value)) {
                  d.standard = value;
                } else {
                  d.formatOverride = value == 'auto'
                      ? null
                      : ConfigFormat.values.byName(value);
                }
                d.validate();
              },
            ),
            if (d.format == ConfigFormat.json && usesJsonSchema(d.standard))
              action(Icons.rule, tr('Esquema', 'Schema'), onSchema),
            PopupMenuButton<String>(
              tooltip: tr('Exportar', 'Export'),
              icon: const Icon(Icons.ios_share, size: 20),
              onSelected: onExport,
              itemBuilder: (_) =>
                  [
                        'json',
                        'yaml',
                        'toml',
                        'ini',
                        'dotenv',
                        'properties',
                        if (tableColumns(d.result?.value) != null) 'csv',
                        'svg',
                        'png',
                      ]
                      .map(
                        (v) => PopupMenuItem(
                          value: v,
                          child: Text(v == 'dotenv' ? 'ENV' : v.toUpperCase()),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      );
    },
  );
}
